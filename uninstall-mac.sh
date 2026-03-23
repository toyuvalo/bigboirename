#!/usr/bin/env bash
# RenameMenu — macOS uninstaller
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW="$HOME/Library/Services/Rename Files with AI.workflow"

echo ""
echo " ================================"
echo "   RenameMenu  —  macOS Uninstall"
echo " ================================"
echo ""

[ -d "$WORKFLOW" ]                   && rm -rf "$WORKFLOW"                  && echo "✓  Removed Quick Action"
[ -f "$SCRIPT_DIR/run-mac.sh" ]      && rm -f  "$SCRIPT_DIR/run-mac.sh"    && echo "✓  Removed launcher"

/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo ""
echo "   Done. The .venv folder and config.json are kept."
echo "   Delete the repo folder to remove everything."
echo ""
