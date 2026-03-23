"""
LLM backend for BigBoiRename — fully local via Ollama.
Providers: ollama | whisper-only
"""
import json
import re
import time
import subprocess


# ── Ollama health + auto-start ────────────────────────────────────────────────

def ensure_ollama(config):
    """
    Check Ollama is reachable. Try to start it if not.
    Returns (ok: bool, error_message: str|None)
    """
    import requests
    url = config.get("ollama_url", "http://localhost:11434")

    # Already running?
    try:
        requests.get(url, timeout=3)
        return True, None
    except Exception:
        pass

    # Try to launch ollama serve — check PATH and known install locations
    ollama_exe = "ollama"
    import os as _os
    for candidate in [
        _os.path.expandvars(r"%LOCALAPPDATA%\Programs\Ollama\ollama.exe"),
        _os.path.expandvars(r"%LOCALAPPDATA%\Ollama\ollama.exe"),
        r"C:\Program Files\Ollama\ollama.exe",
    ]:
        if _os.path.exists(candidate):
            ollama_exe = candidate
            break

    try:
        subprocess.Popen(
            [ollama_exe, "serve"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except FileNotFoundError:
        return False, (
            "Ollama is not installed.\n\n"
            "Run install.ps1 to install it, or download from https://ollama.com"
        )
    except Exception as e:
        return False, f"Could not start Ollama: {e}"

    # Wait up to 12 seconds for it to come up
    for _ in range(12):
        time.sleep(1)
        try:
            requests.get(url, timeout=2)
            return True, None
        except Exception:
            pass

    return False, (
        "Ollama did not start in time.\n\n"
        "Try running 'ollama serve' in a terminal, then retry."
    )


# ── Prompt ────────────────────────────────────────────────────────────────────

def _build_prompt(files):
    lines = []
    for f in files:
        # Escape hint so it can't break the prompt structure
        hint = f.get("hint", "").replace("\\", "\\\\").replace('"', '\\"')[:150]
        hint_part = f' | content hint: {hint}' if hint else ""
        lines.append(f'- {f["name"]}{hint_part}')
    file_list = "\n".join(lines)

    return f"""You are a file renaming assistant. Suggest clean, consistent filenames for this batch.

Rules:
- Keep the original file extension EXACTLY unchanged
- Use descriptive names that reflect the content or subject
- Be consistent in style across the whole batch (prefer snake_case)
- Preserve dates if present and meaningful (e.g. 2024-03-18)
- No special characters except underscores, hyphens, and dots
- Max 60 characters per name
- If a filename is already clean and descriptive, return it unchanged

Files:
{file_list}

Respond ONLY with a valid JSON object mapping original filename -> suggested filename.
Example: {{"WhatsApp Video 2024-03-18 at 1.33.mp4": "birthday_party_2024-03-18.mp4"}}"""


def _parse_json_response(text):
    """
    Robustly extract a JSON object from an LLM response.
    Tolerates markdown fences, extra text, nested braces in values.
    """
    # Strip markdown code fences
    text = re.sub(r"```(?:json)?\s*", "", text).strip().rstrip("`").strip()

    # Direct parse first (cleanest case)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Find outermost { ... } using first { and LAST }
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end > start:
        try:
            return json.loads(text[start : end + 1])
        except json.JSONDecodeError:
            pass

    return {}


def _fallback(files):
    return {f["name"]: f["name"] for f in files}


# ── Provider ──────────────────────────────────────────────────────────────────

def _suggest_ollama(files, config):
    ok, err = ensure_ollama(config)
    if not ok:
        raise RuntimeError(err)

    import requests

    url = config.get("ollama_url", "http://localhost:11434") + "/api/generate"
    model = config.get("ollama_model", "llama3.2:1b")

    payload = {
        "model": model,
        "prompt": _build_prompt(files),
        "stream": False,
        "format": "json",
    }

    try:
        resp = requests.post(url, json=payload, timeout=180)
        resp.raise_for_status()
    except Exception as e:
        raise RuntimeError(f"Ollama request failed: {e}")

    data = resp.json()
    if "error" in data:
        raise RuntimeError(
            f"Ollama error: {data['error']}\n\n"
            f"Is '{model}' installed? Run: ollama pull {model}"
        )

    text = data.get("response", "")
    result = _parse_json_response(text)

    for f in files:
        result.setdefault(f["name"], f["name"])
    return result


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
    if config.get("provider", "ollama") == "whisper-only":
        return _suggest_whisper_only(files)
    return _suggest_ollama(files, config)
