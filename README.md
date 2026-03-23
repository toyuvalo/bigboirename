# RenameMenu

Right-click any folder → AI suggests clean, consistent filenames for everything inside. Fully local — no API keys, no cloud.

Solves the `WhatsApp Video 2024-03-18 at 1.33.mp4` problem.

## How it works

1. Right-click a folder → **"Rename Files with AI"**
2. Local LLM reads filenames (+ optional content hints via Whisper for audio/video)
3. Preview table — see all suggested names, edit inline, check/uncheck
4. Apply — renames are logged so you can undo

---

## Install

### Windows

```powershell
git clone https://github.com/toyuvalo/bigboirename.git
cd bigboirename
powershell -ExecutionPolicy Bypass -File install.ps1
```

Installs Ollama via winget, pulls `llama3.2:1b`, creates a Python venv, and registers the right-click menu under HKCU (no admin needed).

### macOS

```bash
git clone https://github.com/toyuvalo/bigboirename.git
cd bigboirename
bash install-mac.sh
```

Installs Ollama via Homebrew, pulls `llama3.2:1b`, creates a Python venv, and registers a **Finder Quick Action** that appears when you right-click any folder → **Quick Actions → Rename Files with AI**.

> **Requires [Homebrew](https://brew.sh)**

### Linux

```bash
git clone https://github.com/toyuvalo/bigboirename.git
cd bigboirename
bash install-linux.sh
```

Installs Ollama via the official installer script, pulls `llama3.2:1b`, creates a Python venv, and registers:
- **GNOME/Nautilus** — right-click folder → Scripts → Rename Files with AI
- **KDE/Dolphin** — right-click folder → Rename Files with AI (Plasma 5 + 6)

**Total disk footprint: ~1.5 GB** (Ollama ~190 MB + llama3.2:1b ~1.3 GB)

---

## Uninstall

| OS | Command |
|----|---------|
| Windows | `powershell -ExecutionPolicy Bypass -File uninstall.ps1` |
| macOS | `bash uninstall-mac.sh` |
| Linux | `bash uninstall-linux.sh` |

Removes context menu entries. Delete the repo folder and run `ollama rm llama3.2:1b` to remove everything.

---

## Requirements

| OS | Requirements |
|----|-------------|
| Windows | Windows 10/11, Python 3.9+ |
| macOS | macOS 12+, Python 3.9+, Homebrew |
| Linux | Python 3.9+, curl (for Ollama installer) |

---

## Enable Whisper (optional — audio/video content hints)

Whisper transcribes the first 30 seconds of video/audio files to give the LLM real content context instead of just the filename.

1. Uncomment `openai-whisper` in `requirements.txt`
2. Re-run the installer for your OS
3. Requires ffmpeg on PATH for audio trimming

Whisper adds ~2 GB (PyTorch + model weights). The `base` model is a good balance.

---

## Config

`config.json` (gitignored, created from example on install):

| Key | Default | Description |
|---|---|---|
| `provider` | `"ollama"` | `"ollama"` or `"whisper-only"` |
| `ollama_model` | `"llama3.2:1b"` | Any model pulled in Ollama (`llama3.2:3b` for better quality) |
| `ollama_url` | `"http://localhost:11434"` | Ollama server URL |
| `whisper_model` | `"base"` | `tiny` / `base` / `small` / `medium` |
| `scan_contents` | `true` | Read text files / transcribe audio+video |
| `max_files` | `50` | Safety limit per batch |
| `dry_run` | `false` | Preview renames without applying |

---

## Disk usage breakdown

| Component | Size |
|---|---|
| Ollama app | ~190 MB |
| llama3.2:1b model | ~1.3 GB |
| Python venv (requests) | ~15 MB |
| **Total** | **~1.5 GB** |

Want better rename quality? `ollama pull llama3.2:3b` and update `ollama_model` in config.json (~2.2 GB total).

---

Built by [dvlce.ca](https://dvlce.ca)
