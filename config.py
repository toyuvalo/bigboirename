"""
RenameMenu config loader/saver.
config.json lives next to this file and is gitignored — never committed.
"""
import json
import os
import tkinter as tk
from tkinter import simpledialog, messagebox

VERSION = "1.0.0"

_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(_DIR, "config.json")

DEFAULTS = {
    "provider": "gemini",       # "gemini" | "ollama" | "whisper-only"
    "gemini_api_key": "",
    "ollama_model": "llama3.2",
    "ollama_url": "http://localhost:11434",
    "whisper_model": "base",    # tiny | base | small | medium
    "scan_contents": True,
    "max_files": 50,
    "dry_run": False,
}


def load_config():
    if not os.path.exists(CONFIG_PATH):
        cfg = DEFAULTS.copy()
        save_config(cfg)
        return cfg
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    for k, v in DEFAULTS.items():
        if k not in cfg:
            cfg[k] = v
    return cfg


def save_config(cfg):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)


def ensure_api_key(cfg):
    """If provider is gemini and no key set, prompt user and save."""
    if cfg.get("provider") != "gemini":
        return
    if cfg.get("gemini_api_key", "").strip():
        return

    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    key = simpledialog.askstring(
        "RenameMenu — First Run",
        "Enter your Gemini API key\n(free at aistudio.google.com/apikey)\n\n"
        "Saved locally to config.json — never uploaded anywhere.\n"
        "Leave blank to use Ollama (fully local) instead.",
        show="*",
        parent=root,
    )
    root.destroy()

    if key and key.strip():
        cfg["gemini_api_key"] = key.strip()
        save_config(cfg)
    else:
        # fall back to ollama silently
        cfg["provider"] = "ollama"
        save_config(cfg)
