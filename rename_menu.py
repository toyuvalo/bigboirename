#!/usr/bin/env python3
"""
BigBoiRename v1.0.0
Right-click a folder -> AI suggests clean, consistent filenames (fully local).
Usage: python rename_menu.py <folder_path>
"""
import sys
import os
import threading
import tkinter as tk
from tkinter import messagebox

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import load_config, VERSION
from core.scanner import scan_folder
from core.whisper_helper import transcribe_hint, is_available as whisper_available
from core.llm import suggest_names
from core.gui import show_preview
from core.renamer import apply_renames


def main():
    if len(sys.argv) < 2:
        _alert("error", "BigBoiRename", "Usage: rename_menu.py <folder_path>")
        sys.exit(1)

    target = sys.argv[1].strip('"').strip("'")

    # Accept either a folder or a single file
    if os.path.isfile(target):
        folder_path  = os.path.dirname(target)
        single_file  = os.path.basename(target)
    elif os.path.isdir(target):
        folder_path  = target
        single_file  = None
    else:
        _alert("error", "BigBoiRename", f"Not a valid file or folder:\n{target}")
        sys.exit(1)

    cfg = load_config()

    # ── Show loading window while scanning/calling LLM ────────────────────────
    loading, loading_status = _make_loading_window(folder_path)
    process_result = {}

    def _process():
        try:
            loading_status.set("Scanning files...")
            files = scan_folder(
                folder_path,
                scan_contents=cfg.get("scan_contents", True),
                max_files=cfg.get("max_files", 50),
            )
            # Single-file mode: filter to just the right-clicked file
            if single_file:
                files = [f for f in files if f["name"] == single_file]

            if not files:
                process_result["error"] = "No files found in this folder."
                loading.after(0, loading.destroy)
                return

            if cfg.get("scan_contents", True) and whisper_available():
                whisper_model = cfg.get("whisper_model", "base")
                for i, f in enumerate(files):
                    if f["type"] in ("video", "audio") and not f["hint"]:
                        loading_status.set(
                            f"Transcribing {i+1}/{len(files)}: {f['name'][:40]}..."
                        )
                        f["hint"] = transcribe_hint(f["path"], model_name=whisper_model)

            provider = cfg.get("provider", "ollama")
            model = cfg.get("ollama_model", "llama3.2:1b")
            loading_status.set(
                f"Asking {model} for suggestions..." if provider == "ollama"
                else "Building names from transcripts..."
            )
            suggestions = suggest_names(files, cfg)

            process_result["files"] = files
            process_result["suggestions"] = suggestions
        except Exception as e:
            process_result["error"] = str(e)
        finally:
            loading.after(0, loading.destroy)

    t = threading.Thread(target=_process, daemon=True)
    t.start()
    loading.mainloop()
    t.join()

    if "error" in process_result:
        _alert("info", "BigBoiRename", process_result["error"])
        return

    files = process_result["files"]
    suggestions = process_result["suggestions"]

    approved = show_preview(folder_path, files, suggestions)

    if not approved:
        return

    if cfg.get("dry_run", False):
        lines = "\n".join(f"  {k}\n  -> {v}" for k, v in approved.items())
        _alert("info", "BigBoiRename - Dry Run", f"No files changed.\n\n{lines}")
        return

    applied, failed = apply_renames(folder_path, approved)

    if failed:
        fail_lines = "\n".join(f"  {n}: {e}" for n, e in failed)
        _alert(
            "warning", "BigBoiRename",
            f"Renamed {len(applied)} file(s).\n\nFailed ({len(failed)}):\n{fail_lines}",
        )
    else:
        _alert("info", "BigBoiRename", f"Renamed {len(applied)} file(s). Undo log saved in folder.")


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_loading_window(folder_path):
    win = tk.Tk()
    win.title("BigBoiRename")
    win.geometry("420x110")
    win.resizable(False, False)
    win.configure(bg="#1e1e2e")
    win.attributes("-topmost", True)

    tk.Label(win, text="BigBoiRename", bg="#1e1e2e", fg="#89b4fa",
             font=("Segoe UI", 12, "bold")).pack(pady=(16, 4))
    status_var = tk.StringVar(value="Starting...")
    tk.Label(win, textvariable=status_var, bg="#1e1e2e", fg="#a6adc8",
             font=("Segoe UI", 9)).pack()

    win.update()
    return win, status_var


def _alert(level, title, msg):
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    if level == "error":
        messagebox.showerror(title, msg, parent=root)
    elif level == "warning":
        messagebox.showwarning(title, msg, parent=root)
    else:
        messagebox.showinfo(title, msg, parent=root)
    root.destroy()


if __name__ == "__main__":
    main()
