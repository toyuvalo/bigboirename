"""
LLM backend for RenameMenu.
Supports: gemini | ollama | whisper-only
"""
import json
import re


# ── Prompt ────────────────────────────────────────────────────────────────────

def _build_prompt(files):
    lines = []
    for f in files:
        hint_part = f' | content hint: {f["hint"][:150]}' if f.get("hint") else ""
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
    """Extract JSON object from LLM response, tolerating markdown code fences."""
    text = re.sub(r"```(?:json)?\s*", "", text).strip().rstrip("`").strip()
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass
    return {}


def _fallback(files):
    """Return original names unchanged — used when LLM call fails."""
    return {f["name"]: f["name"] for f in files}


# ── Providers ─────────────────────────────────────────────────────────────────

def _suggest_gemini(files, config):
    try:
        import google.generativeai as genai

        genai.configure(api_key=config["gemini_api_key"])
        model = genai.GenerativeModel("gemini-2.0-flash")
        response = model.generate_content(_build_prompt(files))
        result = _parse_json_response(response.text)
        # Fill any missing keys with original name
        for f in files:
            result.setdefault(f["name"], f["name"])
        return result
    except Exception as e:
        print(f"[RenameMenu] Gemini error: {e}")
        return _fallback(files)


def _suggest_ollama(files, config):
    try:
        import requests

        url = config.get("ollama_url", "http://localhost:11434") + "/api/generate"
        payload = {
            "model": config.get("ollama_model", "llama3.2"),
            "prompt": _build_prompt(files),
            "stream": False,
            "format": "json",
        }
        resp = requests.post(url, json=payload, timeout=120)
        resp.raise_for_status()
        text = resp.json().get("response", "")
        result = _parse_json_response(text)
        for f in files:
            result.setdefault(f["name"], f["name"])
        return result
    except Exception as e:
        print(f"[RenameMenu] Ollama error: {e}")
        return _fallback(files)


def _suggest_whisper_only(files):
    """
    Build a name purely from the Whisper hint — no LLM call.
    Useful as a free, offline fallback for audio/video files.
    """
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
    Returns dict {original_filename: suggested_filename} for all files.
    Provider selected from config["provider"].
    """
    if not files:
        return {}

    provider = config.get("provider", "gemini")

    if provider == "gemini":
        return _suggest_gemini(files, config)
    elif provider == "ollama":
        return _suggest_ollama(files, config)
    else:
        return _suggest_whisper_only(files)
