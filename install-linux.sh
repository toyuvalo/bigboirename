#!/usr/bin/env bash
# RenameMenu — Linux installer
# Registers right-click entry for GNOME/Nautilus and KDE/Dolphin.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo " ================================"
echo "   RenameMenu  —  Linux Setup"
echo " ================================"
echo ""

# ── Python ────────────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "✗  Python 3 not found."
    echo "   Ubuntu/Debian:  sudo apt install python3 python3-pip python3-venv"
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

echo "   Installing dependencies..."
"$VENV/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"
echo "✓  Dependencies installed"
echo ""

# ── Ollama ────────────────────────────────────────────────────────────────────
if command -v ollama &>/dev/null; then
    echo "✓  Ollama: $(command -v ollama)"
else
    echo "   Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo "✓  Ollama installed"
fi

MODEL=$(python3 -c "import json,os; d=os.path.join('$SCRIPT_DIR','config.json'); c=json.load(open(d)) if os.path.exists(d) else {}; print(c.get('ollama_model','llama3.2:1b'))" 2>/dev/null || echo "llama3.2:1b")
if ! ollama list 2>/dev/null | grep -q "${MODEL%%:*}"; then
    echo "   Pulling $MODEL (~1.3 GB, one-time)..."
    ollama pull "$MODEL"
    echo "✓  Model ready"
else
    echo "✓  Model $MODEL already present"
fi

if [ ! -f "$SCRIPT_DIR/config.json" ] && [ -f "$SCRIPT_DIR/config.json.example" ]; then
    cp "$SCRIPT_DIR/config.json.example" "$SCRIPT_DIR/config.json"
    echo "✓  config.json created"
fi
echo ""

# ── GNOME / Nautilus ──────────────────────────────────────────────────────────
NAUTILUS_SCRIPTS="$HOME/.local/share/nautilus/scripts"
mkdir -p "$NAUTILUS_SCRIPTS"

cat > "$NAUTILUS_SCRIPTS/Rename Files with AI" << NSCRIPT
#!/usr/bin/env bash
# Nautilus passes selected items via env var (newline-separated)
IFS=\$'\n'
for f in \$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS; do
    [ -z "\$f" ] && continue
    "$SCRIPT_DIR/.venv/bin/python" "$SCRIPT_DIR/rename_menu.py" "\$f" &
done
NSCRIPT
chmod +x "$NAUTILUS_SCRIPTS/Rename Files with AI"
echo "✓  GNOME/Nautilus script registered"

# ── KDE / Dolphin ─────────────────────────────────────────────────────────────
for DOLPHIN_DIR in "$HOME/.local/share/kservices5/ServiceMenus" "$HOME/.local/share/kio/servicemenus"; do
    mkdir -p "$DOLPHIN_DIR"
    cat > "$DOLPHIN_DIR/renamemenu.desktop" << DESKTOP
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;
Actions=renamemenu_rename;
X-KDE-Priority=TopLevel

[Desktop Action renamemenu_rename]
Name=Rename Files with AI
Icon=edit-rename
Exec=$SCRIPT_DIR/.venv/bin/python $SCRIPT_DIR/rename_menu.py %f
DESKTOP
done
echo "✓  KDE/Dolphin service menu registered (Plasma 5 + 6)"

echo ""
echo " ================================"
echo "   Done!"
echo " ================================"
echo ""
echo "   GNOME: right-click a folder → Scripts → Rename Files with AI"
echo "   KDE:   right-click a folder → Rename Files with AI"
echo ""
echo "   To restart Nautilus:  nautilus -q"
echo "   To rebuild KDE cache: kbuildsycoca6 --noincremental"
echo ""
