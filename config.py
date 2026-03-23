"""
BigBoiRename config loader/saver.
config.json lives next to this file and is gitignored — never committed.
"""
import json
import os

VERSION = "1.0.0"

_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(_DIR, "config.json")

DEFAULTS = {
    "provider": "ollama",
    "ollama_model": "llama3.2:1b",
    "ollama_url": "http://localhost:11434",
    "whisper_model": "base",
    "scan_contents": True,
    "max_files": 50,
    "dry_run": False,
}


def load_config():
    if not os.path.exists(CONFIG_PATH):
        cfg = DEFAULTS.copy()
        save_config(cfg)
        return cfg
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            cfg = json.load(f)
    except (json.JSONDecodeError, OSError):
        # Corrupt or unreadable config — reset to defaults
        cfg = DEFAULTS.copy()
        save_config(cfg)
        return cfg

    for k, v in DEFAULTS.items():
        if k not in cfg:
            cfg[k] = v
    return cfg


def save_config(cfg):
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except OSError:
        pass
