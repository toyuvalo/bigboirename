"""
LLM backend for BigBoiRename v1.1.0
Providers: gemini (default) | ollama | whisper-only

Gemini uses vision — video frames extracted via ffmpeg, images read directly.
No CLI windows, no visible processes.
"""
import json
import re
import time
import subprocess
import os
import tempfile


# ── Visual content extraction ─────────────────────────────────────────────────

def _extract_video_frame(video_path):
    """
    Extract a single representative frame from a video using ffmpeg.
    Returns JPEG bytes, or None if ffmpeg isn't available or fails.
    Runs completely silently (CREATE_NO_WINDOW).
    """
    tmp = tempfile.mktemp(suffix=".jpg")
    try:
        subprocess.run(
            [
                "ffmpeg", "-i", video_path,
                "-vframes", "1",
                "-q:v", "3",
                "-vf", "scale=800:-1",
                tmp, "-y",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            timeout=15,
        )
        if os.path.exists(tmp):
            with open(tmp, "rb") as f:
                data = f.read()
            return data if data else None
    except Exception:
        return None
    finally:
        try:
            if os.path.exists(tmp):
                os.unlink(tmp)
        except Exception:
            pass


def _load_image_bytes(path, ext):
    """Load image file as raw bytes. Returns (bytes, mime) or (None, None)."""
    try:
        with open(path, "rb") as f:
            data = f.read()
        mime = {
            ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
            ".png": "image/png",  ".webp": "image/webp",
            ".gif": "image/gif",  ".heic": "image/heic",
            ".heif": "image/heic",
        }.get(ext.lower(), "image/jpeg")
        return data, mime
    except Exception:
        return None, None


# ── Gemini API key ────────────────────────────────────────────────────────────

def _get_or_prompt_api_key(config):
    """Return Gemini API key from config, prompting via tkinter dialog if missing."""
    key = config.get("gemini_api_key", "").strip()
    if key:
        return key

    import tkinter as tk
    from tkinter import simpledialog

    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    key = simpledialog.askstring(
        "BigBoiRename — First Run Setup",
        "A free Gemini API key is required.\n\n"
        "Get one at:  https://aistudio.google.com/\n\n"
        "Paste your key below:",
        parent=root,
    )
    root.destroy()

    if not key or not key.strip():
        raise RuntimeError(
            "No Gemini API key provided.\n\n"
            "Get a free key at:\nhttps://aistudio.google.com/"
        )
    key = key.strip()

    # Persist to config.json so user is never asked again
    from config import load_config, save_config
    cfg = load_config()
    cfg["gemini_api_key"] = key
    save_config(cfg)
    return key


# ── Prompt builder ────────────────────────────────────────────────────────────

def _build_prompt(files):
    lines = []
    for f in files:
        has_visual = f.get("_has_visual", False)
        hint = f.get("hint", "").replace("\\", "\\\\").replace('"', '\\"')[:400]
        if has_visual:
            lines.append(f'- filename: {f["name"]}  (visual shown above — use what you see)')
        elif hint:
            lines.append(f'- filename: {f["name"]}\n  content: {hint}')
        else:
            lines.append(f'- filename: {f["name"]}  (no content available)')
    file_list = "\n".join(lines)

    return (
        "You are a file renaming assistant. Rename each file based on what is ACTUALLY in it.\n\n"
        "Rules:\n"
        "- For visual files (images/videos), describe the actual subject visible in the frame: "
        "person, place, event, activity, object.\n"
        "- For text/audio, use the actual subject matter from the content hint.\n"
        "- snake_case, max 60 chars, only letters/numbers/underscores/hyphens/dots.\n"
        "- Keep the EXACT original file extension.\n"
        "- Preserve dates if present (e.g. 2024-03-18).\n"
        "- NEVER just reformat the original filename. The name MUST reflect real content.\n"
        "- If you truly cannot determine content, make a reasonable guess from any available clues.\n\n"
        f"Files:\n{file_list}\n\n"
        "Respond ONLY with a JSON object mapping original filenames to new filenames.\n"
        'Example: {"old_name.mp4": "descriptive_name.mp4"}'
    )


def _parse_json_response(text):
    text = re.sub(r"```(?:json)?\s*", "", text).strip().rstrip("`").strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end > start:
        try:
            return json.loads(text[start : end + 1])
        except json.JSONDecodeError:
            pass
    return {}


# ── Gemini provider ───────────────────────────────────────────────────────────

def _suggest_gemini(files, config):
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        raise RuntimeError(
            "google-genai package not installed.\n\n"
            "Run:  pip install google-genai  in the RenameMenu venv."
        )

    key = _get_or_prompt_api_key(config)
    client = genai.Client(api_key=key)

    parts = []
    for f in files:
        visual_bytes = None
        mime = "image/jpeg"

        if f["type"] == "video":
            visual_bytes = _extract_video_frame(f["path"])
        elif f["type"] == "image":
            visual_bytes, mime = _load_image_bytes(f["path"], f["ext"])

        if visual_bytes:
            try:
                parts.append(types.Part.from_bytes(data=visual_bytes, mime_type=mime))
                f["_has_visual"] = True
            except Exception:
                pass  # visual failed — fall through to text-only for this file

    parts.append(_build_prompt(files))

    try:
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=parts,
        )
        text = response.text
    except Exception as e:
        raise RuntimeError(f"Gemini request failed: {e}")

    raw = _parse_json_response(text)
    input_names = {f["name"] for f in files}
    result = {k: v for k, v in raw.items() if k in input_names}
    for f in files:
        result.setdefault(f["name"], f["name"])
    return result


# ── Ollama provider (fallback) ────────────────────────────────────────────────

def ensure_ollama(config):
    import requests as _req
    url = config.get("ollama_url", "http://localhost:11434")
    try:
        _req.get(url, timeout=3)
        return True, None
    except Exception:
        pass

    import sys as _sys
    ollama_exe = "ollama"
    if _sys.platform == "win32":
        for c in [
            os.path.expandvars(r"%LOCALAPPDATA%\Programs\Ollama\ollama.exe"),
            os.path.expandvars(r"%LOCALAPPDATA%\Ollama\ollama.exe"),
            r"C:\Program Files\Ollama\ollama.exe",
        ]:
            if os.path.exists(c):
                ollama_exe = c
                break

    try:
        subprocess.Popen(
            [ollama_exe, "serve"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except FileNotFoundError:
        return False, "Ollama is not installed.\n\nDownload from https://ollama.com"
    except Exception as e:
        return False, f"Could not start Ollama: {e}"

    for _ in range(12):
        time.sleep(1)
        try:
            _req.get(url, timeout=2)
            return True, None
        except Exception:
            pass
    return False, "Ollama did not start in time."


def _suggest_ollama(files, config):
    ok, err = ensure_ollama(config)
    if not ok:
        raise RuntimeError(err)

    import requests as _req
    url = config.get("ollama_url", "http://localhost:11434") + "/api/generate"
    model = config.get("ollama_model", "llama3.2:1b")
    payload = {
        "model": model,
        "prompt": _build_prompt(files),
        "stream": False,
        "format": "json",
    }
    try:
        resp = _req.post(url, json=payload, timeout=180)
        resp.raise_for_status()
    except Exception as e:
        raise RuntimeError(f"Ollama request failed: {e}")

    data = resp.json()
    if "error" in data:
        raise RuntimeError(
            f"Ollama error: {data['error']}\n\nRun: ollama pull {model}"
        )

    raw = _parse_json_response(data.get("response", ""))
    input_names = {f["name"] for f in files}
    result = {k: v for k, v in raw.items() if k in input_names}
    for f in files:
        result.setdefault(f["name"], f["name"])
    return result


# ── Whisper-only provider ─────────────────────────────────────────────────────

def _suggest_whisper_only(files):
    result = {}
    for f in files:
        hint = f.get("hint", "").strip()
        if hint:
            words = re.sub(r"[^\w\s]", "", hint).split()[:7]
            base = "_".join(w.lower() for w in words if w)
            if base:
                result[f["name"]] = f"{base}{f['ext']}"
                continue
        result[f["name"]] = f["name"]
    return result


# ── Public API ────────────────────────────────────────────────────────────────

def suggest_names(files, config):
    """
    Returns dict {original_filename: suggested_filename}.
    Raises RuntimeError with a user-readable message on failure.
    """
    if not files:
        return {}
    provider = config.get("provider", "gemini")
    if provider == "whisper-only":
        return _suggest_whisper_only(files)
    if provider == "ollama":
        return _suggest_ollama(files, config)
    return _suggest_gemini(files, config)
