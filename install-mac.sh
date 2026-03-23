#!/usr/bin/env bash
# RenameMenu — macOS installer
# Registers a Finder Quick Action for folders and files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_DIR="$HOME/Library/Services"
WORKFLOW="$SERVICE_DIR/Rename Files with AI.workflow"

echo ""
echo " ================================"
echo "   RenameMenu  —  macOS Setup"
echo " ================================"
echo ""

# ── Python ────────────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "✗  Python 3 not found. Install from https://python.org"
    exit 1
fi
PY="$(command -v python3)"
echo "✓  Python $($PY --version 2>&1 | awk '{print $2}')  →  $PY"
echo ""

# ── Virtual environment + deps ────────────────────────────────────────────────
VENV="$SCRIPT_DIR/.venv"
if [ ! -f "$VENV/bin/python" ]; then
    echo "   Creating virtual environment..."
    $PY -m venv "$VENV"
    echo "✓  venv created"
fi
VENV_PY="$VENV/bin/python"

echo "   Installing dependencies..."
"$VENV/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"
echo "✓  Dependencies installed"
echo ""

# ── Ollama ────────────────────────────────────────────────────────────────────
if command -v ollama &>/dev/null || [ -f "/usr/local/bin/ollama" ] || [ -f "/opt/homebrew/bin/ollama" ]; then
    echo "✓  Ollama found: $(command -v ollama 2>/dev/null || echo 'installed')"
else
    if command -v brew &>/dev/null; then
        echo "   Installing Ollama via Homebrew..."
        brew install ollama --quiet
        echo "✓  Ollama installed"
    else
        echo "   Ollama not found. Install from https://ollama.com/download"
        echo "   Then pull a model:  ollama pull llama3.2:1b"
        echo "   Then re-run this script."
        exit 1
    fi
fi

# Pull model if not already present
MODEL=$(python3 -c "import json,os; d=os.path.join('$SCRIPT_DIR','config.json'); c=json.load(open(d)) if os.path.exists(d) else {}; print(c.get('ollama_model','llama3.2:1b'))" 2>/dev/null || echo "llama3.2:1b")
if ! ollama list 2>/dev/null | grep -q "${MODEL%%:*}"; then
    echo "   Pulling $MODEL (~1.3 GB, one-time)..."
    ollama pull "$MODEL"
    echo "✓  Model ready"
else
    echo "✓  Model $MODEL already present"
fi

# Bootstrap config.json if missing
if [ ! -f "$SCRIPT_DIR/config.json" ] && [ -f "$SCRIPT_DIR/config.json.example" ]; then
    cp "$SCRIPT_DIR/config.json.example" "$SCRIPT_DIR/config.json"
    echo "✓  config.json created from example"
fi
echo ""

# ── Launcher shell script ─────────────────────────────────────────────────────
cat > "$SCRIPT_DIR/run-mac.sh" << RUNSH
#!/usr/bin/env bash
exec "$VENV/bin/python" "$SCRIPT_DIR/rename_menu.py" "\$1"
RUNSH
chmod +x "$SCRIPT_DIR/run-mac.sh"
echo "✓  Launcher created: run-mac.sh"
echo ""

# ── Automator Quick Action ────────────────────────────────────────────────────
echo "   Registering Finder Quick Action..."
mkdir -p "$WORKFLOW/Contents"

cat > "$WORKFLOW/Contents/Info.plist" << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Rename Files with AI</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.folder</string>
				<string>public.item</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
INFOPLIST

ESCAPED_DIR="$(printf '%s' "$SCRIPT_DIR" | sed 's/&/\&amp;/g')"

cat > "$WORKFLOW/Contents/document.wflow" << WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>521</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>for f in "\$@"; do
    "$ESCAPED_DIR/run-mac.sh" "\$f" &amp;
done</string>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string>pass-as-arguments</string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.automator.runShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>UUID</key>
				<string>BB22CC33-DD44-EE55-FF66-RENAMEMENU001</string>
				<key>isViewVisible</key>
				<true/>
			</dict>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW

echo "✓  Quick Action → $WORKFLOW"
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo ""
echo " ================================"
echo "   Done!"
echo " ================================"
echo ""
echo "   Right-click any folder (or file) in Finder"
echo "   → Quick Actions → Rename Files with AI"
echo ""
echo "   If the option doesn't appear:"
echo "   System Settings → Privacy & Security → Extensions"
echo "   → Added Extensions → Finder → enable RenameMenu"
echo ""
