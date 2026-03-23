"""
Optional Whisper integration — transcribes first N seconds of audio/video
to give the LLM a content hint. Gracefully skipped if whisper not installed.
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


def transcribe_hint(path, model_name="base", max_seconds=30, max_chars=200):
    """
    Transcribe first max_seconds of an audio/video file.
    Returns a short transcript string, or '' on any failure.
    """
    if not is_available():
        return ""
    try:
        import whisper

        audio_path = _trim_audio(path, max_seconds)
        model = whisper.load_model(model_name)
        result = model.transcribe(audio_path, fp16=False, verbose=False)
        text = result.get("text", "").strip()

        if audio_path != path:
            try:
                os.remove(audio_path)
            except Exception:
                pass

        return text[:max_chars]
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
                tmp,
            ],
            capture_output=True,
            timeout=30,
        )
        if result.returncode == 0 and os.path.exists(tmp):
            return tmp
    except Exception:
        pass
    return path
