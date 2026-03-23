"""
Scans a folder, categorizes files, and extracts content hints for the LLM.
"""
import os

VIDEO_EXTS = {".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v", ".wmv", ".flv", ".3gp"}
AUDIO_EXTS = {".mp3", ".wav", ".m4a", ".ogg", ".flac", ".aac", ".wma", ".opus"}
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".heif", ".bmp", ".tiff", ".tif", ".svg"}
TEXT_EXTS = {
    ".txt", ".md", ".py", ".js", ".ts", ".html", ".css", ".json", ".xml",
    ".csv", ".log", ".sh", ".bat", ".ps1", ".yaml", ".yml", ".toml",
    ".ini", ".cfg", ".conf", ".rst", ".java", ".c", ".cpp", ".h",
    ".go", ".rs", ".rb", ".php", ".sql",
}


def get_file_type(ext):
    ext = ext.lower()
    if ext in VIDEO_EXTS:
        return "video"
    if ext in AUDIO_EXTS:
        return "audio"
    if ext in IMAGE_EXTS:
        return "image"
    if ext in TEXT_EXTS:
        return "text"
    return "other"


def _extract_text_hint(path, max_chars=500):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read(max_chars).strip()
    except Exception:
        return ""


def scan_folder(folder_path, scan_contents=True, max_files=50):
    """
    Returns list of file dicts for files directly in folder_path (non-recursive).
    Each dict: {name, path, ext, type, hint}
    """
    files = []
    try:
        entries = sorted(os.listdir(folder_path))
    except PermissionError:
        return files

    for name in entries:
        if len(files) >= max_files:
            break
        full_path = os.path.join(folder_path, name)
        if not os.path.isfile(full_path):
            continue
        # Skip our own undo log
        if name == "bigboirename_undo.json":
            continue

        _, ext = os.path.splitext(name)
        file_type = get_file_type(ext)
        hint = ""
        if scan_contents and file_type == "text":
            hint = _extract_text_hint(full_path)

        files.append({
            "name": name,
            "path": full_path,
            "ext": ext.lower(),
            "type": file_type,
            "hint": hint,
        })

    return files
