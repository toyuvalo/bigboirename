"""
Applies renames and maintains an undo log (bigboirename_undo.json) in the target folder.
"""
import os
import json
from datetime import datetime

# Windows reserved filenames (case-insensitive, with or without extension)
_RESERVED = {
    "CON", "PRN", "AUX", "NUL",
    "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
    "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
}
_INVALID_CHARS = set('<>:"/\\|?*') | {chr(i) for i in range(32)}


def validate_filename(name):
    """Returns (is_valid: bool, reason: str|None)"""
    if not name or not name.strip():
        return False, "empty filename"
    if len(name) > 255:
        return False, "exceeds 255-character limit"
    if any(c in _INVALID_CHARS for c in name):
        bad = [c for c in name if c in _INVALID_CHARS]
        return False, f"contains invalid character(s): {bad}"
    stem = os.path.splitext(name)[0].upper()
    if stem in _RESERVED:
        return False, f"'{stem}' is a reserved Windows name"
    if name.endswith(".") or name.endswith(" "):
        return False, "filename cannot end with '.' or space"
    return True, None


def apply_renames(folder_path, renames):
    """
    renames: dict {old_name: new_name}
    Returns (applied: list[(old, new)], failed: list[(old, reason)])
    """
    applied = []
    failed = []

    for old_name, new_name in renames.items():
        if not new_name or new_name == old_name:
            continue

        # Validate the new name
        valid, reason = validate_filename(new_name)
        if not valid:
            failed.append((old_name, f"bad filename: {reason}"))
            continue

        old_path = os.path.join(folder_path, old_name)
        resolved = _resolve_conflict(folder_path, new_name)
        new_path = os.path.join(folder_path, resolved)

        if not os.path.exists(old_path):
            failed.append((old_name, "source file not found"))
            continue

        try:
            os.rename(old_path, new_path)
            applied.append((old_name, resolved))
        except PermissionError:
            failed.append((old_name, "permission denied — file may be open"))
        except OSError as e:
            failed.append((old_name, str(e)))

    if applied:
        _write_undo(folder_path, applied)

    return applied, failed


def undo_last(folder_path):
    """
    Reverses the most recent rename batch in bigboirename_undo.json.
    Returns (reversed: list[(new, old)], error: str|None)
    """
    undo_path = os.path.join(folder_path, "bigboirename_undo.json")
    if not os.path.exists(undo_path):
        return [], "No undo log found in this folder."

    try:
        with open(undo_path, "r", encoding="utf-8") as f:
            log = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        return [], f"Could not read undo log: {e}"

    entries = log.get("entries", [])
    if not entries:
        return [], "Undo log is empty."

    last = entries[-1]
    reversed_pairs = []

    for old_name, new_name in last["renames"]:
        new_path = os.path.join(folder_path, new_name)
        old_path = os.path.join(folder_path, old_name)
        if os.path.exists(new_path) and not os.path.exists(old_path):
            try:
                os.rename(new_path, old_path)
                reversed_pairs.append((new_name, old_name))
            except OSError:
                pass

    log["entries"] = entries[:-1]
    try:
        with open(undo_path, "w", encoding="utf-8") as f:
            json.dump(log, f, indent=2)
    except OSError:
        pass  # undo still happened in-memory; log just wasn't updated

    return reversed_pairs, None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _resolve_conflict(folder_path, name):
    if not os.path.exists(os.path.join(folder_path, name)):
        return name
    base, ext = os.path.splitext(name)
    i = 1
    while True:
        candidate = f"{base}_{i}{ext}"
        if not os.path.exists(os.path.join(folder_path, candidate)):
            return candidate
        i += 1


def _write_undo(folder_path, applied):
    undo_path = os.path.join(folder_path, "bigboirename_undo.json")
    log = {"entries": []}
    if os.path.exists(undo_path):
        try:
            with open(undo_path, "r", encoding="utf-8") as f:
                log = json.load(f)
        except (json.JSONDecodeError, OSError):
            log = {"entries": []}  # corrupt log — start fresh

    log["entries"].append({
        "timestamp": datetime.now().isoformat(),
        "renames": applied,
    })
    log["entries"] = log["entries"][-10:]

    try:
        with open(undo_path, "w", encoding="utf-8") as f:
            json.dump(log, f, indent=2)
    except OSError:
        pass  # network drive / permission issue — renames still applied
