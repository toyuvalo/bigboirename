#!/usr/bin/env bash
# RenameMenu — Linux uninstaller
set -euo pipefail

NAUTILUS="$HOME/.local/share/nautilus/scripts/Rename Files with AI"
DOLPHIN5="$HOME/.local/share/kservices5/ServiceMenus/renamemenu.desktop"
DOLPHIN6="$HOME/.local/share/kio/servicemenus/renamemenu.desktop"

echo ""
echo " ================================"
echo "   RenameMenu  —  Linux Uninstall"
echo " ================================"
echo ""

[ -f "$NAUTILUS" ]  && rm -f "$NAUTILUS"  && echo "✓  Removed Nautilus script"
[ -f "$DOLPHIN5" ]  && rm -f "$DOLPHIN5"  && echo "✓  Removed KDE Plasma 5 service menu"
[ -f "$DOLPHIN6" ]  && rm -f "$DOLPHIN6"  && echo "✓  Removed KDE Plasma 6 service menu"

echo ""
echo "   Done. The .venv folder and config.json are kept."
echo "   Delete the repo folder to remove everything."
echo ""
