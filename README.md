# RenameMenu

Right-click any folder → AI suggests clean, consistent filenames for everything inside. Fully local — no API keys, no cloud.

Solves the `WhatsApp Video 2024-03-18 at 1.33.mp4` problem.

## How it works

1. Right-click a folder → **"Rename Files with AI"**
2. Local LLM reads filenames (+ optional content hints via Whisper for audio/video)
3. Preview table — see all suggested names, edit inline, check/uncheck
4. Apply — renames are logged so you can undo

## Install

```powershell
git clone https://github.com/toyuvalo/renamemenu.git
cd renamemenu
powershell -ExecutionPolicy Bypass -File install.ps1
```

The installer will:
- Install **Ollama** via winget (if not already installed)
- Pull **llama3.2:1b** (~1.3 GB, one-time download)
- Create a Python venv and install dependencies
- Register the right-click menu under HKCU (no admin needed)

**Total disk footprint: ~1.5 GB**

## Requirements

- Windows 10/11
- Python 3.9+
- Internet for first-time model download (~1.3 GB), offline forever after

## Enable Whisper (optional — audio/video hints)

Whisper transcribes the first 30 seconds of video/audio files to give the model real content context instead of just the filename.

1. Uncomment `openai-whisper` in `requirements.txt`
2. Re-run: `powershell -ExecutionPolicy Bypass -File install.ps1`
3. Requires ffmpeg on PATH for audio trimming

Whisper adds ~2 GB (PyTorch + model weights). The `base` model is a good balance of speed and accuracy.

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

## Disk usage breakdown

| Component | Size |
|---|---|
| Ollama app | ~190 MB |
| llama3.2:1b model | ~1.3 GB |
| Python venv (requests) | ~15 MB |
| **Total** | **~1.5 GB** |

Want better rename quality? `ollama pull llama3.2:3b` and update `ollama_model` in config.json (~2.2 GB total).

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

Removes the context menu entry. Delete the folder to remove everything.
To remove the Ollama model: `ollama rm llama3.2:1b`
