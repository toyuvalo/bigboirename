"""
Whisper transcription + translation for BigBoiRename.
Always translates output to English so the LLM can name non-English content correctly.
"""
import os
import tempfile

_whisper_available = None


def is_available():
    global _whisper_available
    if _whisper_available is None:
        try:
            import whisper  # noqa: F401
            _whisper_available = True
        except ImportError:
            _whisper_available = False
    return _whisper_available


def transcribe_hint(path, model_name="base", max_seconds=60, max_chars=500):
    """
    Transcribe audio/video and translate to English.
    Returns an English transcript snippet, or '' on failure.

    Uses task="translate" so Hebrew, Arabic, French, Spanish, etc.
    all come out as English — giving the LLM real content to name from.
    """
    if not is_available():
        return ""
    try:
        import whisper

        audio_path = _trim_audio(path, max_seconds)
        model = whisper.load_model(model_name)

        # translate = transcribe + translate to English in one pass
        result = model.transcribe(
            audio_path,
            task="translate",      # always output English
            fp16=False,
            verbose=False,
        )
        text = result.get("text", "").strip()
        detected_lang = result.get("language", "unknown")

        if audio_path != path:
            try:
                os.remove(audio_path)
            except Exception:
                pass

        # Prefix with detected language so LLM knows it was translated
        prefix = f"[translated from {detected_lang}] " if detected_lang not in ("en", "english") else ""
        return (prefix + text)[:max_chars]

    except Exception:
        return ""


def _trim_audio(path, seconds):
    """Use ffmpeg to extract first N seconds as 16kHz mono WAV. Falls back to original."""
    try:
        import subprocess

        tmp = tempfile.mktemp(suffix=".wav")
        result = subprocess.run(
            [
                "ffmpeg", "-y", "-i", path,
                "-t", str(seconds),
                "-ar", "16000",
                "-ac", "1",
                "-vn",   # no video stream
                tmp,
            ],
            capture_output=True,
            timeout=60,
        )
        if result.returncode == 0 and os.path.exists(tmp):
            return tmp
    except Exception:
        pass
    return path
