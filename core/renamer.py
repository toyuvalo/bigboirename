"""
Applies renames and maintains an undo log (bigboirename_undo.json) in the target folder.
"""
import os
import json
from datetime import datetime


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

        old_path = os.path.join(folder_path, old_name)
        resolved = _resolve_conflict(folder_path, new_name)
        new_path = os.path.join(folder_path, resolved)

        if not os.path.exists(old_path):
            failed.append((old_name, "source file not found"))
            continue

        try:
            os.rename(old_path, new_path)
            applied.append((old_name, resolved))
        except Exception as e:
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

    with open(undo_path, "r", encoding="utf-8") as f:
        log = json.load(f)

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
            except Exception:
                pass

    log["entries"] = entries[:-1]
    with open(undo_path, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2)

    return reversed_pairs, None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _resolve_conflict(folder_path, name):
    """Append _1, _2, etc. if name already exists."""
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
    if os.path.exists(undo_path):
        with open(undo_path, "r", encoding="utf-8") as f:
            log = json.load(f)
    else:
        log = {"entries": []}

    log["entries"].append({
        "timestamp": datetime.now().isoformat(),
        "renames": applied,  # list of [old, new]
    })
    log["entries"] = log["entries"][-10:]  # keep last 10 batches

    with open(undo_path, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2)
