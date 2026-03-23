# RenameMenu launcher — called by Windows Explorer context menu
# Do not run this directly; use install.ps1 to register it.
param([string]$FolderPath)

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VenvPython = Join-Path $ScriptDir '.venv\Scripts\python.exe'
$MainScript = Join-Path $ScriptDir 'rename_menu.py'

if (-not (Test-Path $VenvPython)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "RenameMenu is not installed.`nRun install.ps1 first.",
        "RenameMenu", "OK", "Error"
    ) | Out-Null
    exit 1
}

& $VenvPython $MainScript $FolderPath
