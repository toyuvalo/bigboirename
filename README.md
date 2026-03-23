# RenameMenu

Right-click any folder → AI suggests clean, consistent filenames for everything inside.

Solves the `WhatsApp Video 2024-03-18 at 1.33.mp4` problem.

![preview](https://raw.githubusercontent.com/toyuvalo/renamemenu/main/docs/preview.png)

## Features

- **Right-click any folder** in Windows Explorer → "Rename Files with AI"
- **Three modes** — choose what works for you:
  | Mode | How | Cost | Offline? |
  |---|---|---|---|
  | `gemini` | Gemini 2.0 Flash API | Free tier (1500 req/day) | No |
  | `ollama` | Local LLM via Ollama | Free | Yes |
  | `whisper-only` | Whisper transcript → name | Free | Yes |
- **Audio/Video hints** — optionally transcribes first 30s with Whisper to give the LLM real context
- **Preview table** — see all suggested names before anything changes; edit inline
- **Undo** — every rename batch is logged to `renamemenu_undo.json` in the folder
- **No admin required** — context menu registered under HKCU

## Install

```powershell
git clone https://github.com/toyuvalo/renamemenu.git
cd renamemenu
powershell -ExecutionPolicy Bypass -File install.ps1
```

That's it. On first run you'll be prompted for your Gemini API key, or leave it blank to use Ollama instead.

## Get a free Gemini API key

1. Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Click **Create API Key**
3. Paste it when RenameMenu prompts you on first run

Free tier: 1,500 requests/day, 1M tokens/minute — far more than you'll ever use for renaming.

## Use Ollama instead (fully local, no API key)

1. Install [Ollama](https://ollama.com)
2. Run `ollama pull llama3.2`
3. Edit `config.json` → set `"provider": "ollama"`

## Enable Whisper (audio/video transcription)

Whisper is optional and requires PyTorch (~2GB). To enable:

1. Uncomment `openai-whisper` in `requirements.txt`
2. Re-run the installer: `powershell -ExecutionPolicy Bypass -File install.ps1`
3. Set `"whisper_model": "base"` in `config.json` (tiny/base/small/medium)

The first run will download the model weights automatically.

## Config reference

`config.json` (created from `config.json.example` on install, gitignored):

| Key | Default | Description |
|---|---|---|
| `provider` | `"gemini"` | `"gemini"` / `"ollama"` / `"whisper-only"` |
| `gemini_api_key` | `""` | Your Gemini API key |
| `ollama_model` | `"llama3.2"` | Any model you have pulled in Ollama |
| `ollama_url` | `"http://localhost:11434"` | Ollama server URL |
| `whisper_model` | `"base"` | `tiny` / `base` / `small` / `medium` |
| `scan_contents` | `true` | Read text file content / transcribe audio+video |
| `max_files` | `50` | Safety limit per batch |
| `dry_run` | `false` | Preview renames without applying them |

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

Removes the context menu entry. Delete the folder to remove everything.

## Requirements

- Windows 10/11
- Python 3.9+
- ffmpeg on PATH (for Whisper audio trimming — optional)
