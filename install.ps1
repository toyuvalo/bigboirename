# RenameMenu installer
# Registers right-click context menu on folders. No admin required.
# Run once after cloning: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "RenameMenu Installer" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Python check --------------------------------------------------------
$PythonExe = $null
foreach ($candidate in @('python', 'python3', 'py')) {
    try {
        $ver = & $candidate --version 2>&1
        if ($ver -match 'Python 3') { $PythonExe = $candidate; break }
    } catch {}
}
if (-not $PythonExe) {
    Write-Host "ERROR: Python 3 not found. Install from python.org." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Python found: $($PythonExe)" -ForegroundColor Green

# ---- 2. Create virtualenv ---------------------------------------------------
$VenvDir    = Join-Path $ScriptDir '.venv'
$VenvPython = Join-Path $VenvDir 'Scripts\python.exe'

if (-not (Test-Path $VenvPython)) {
    Write-Host "[..] Creating virtual environment..." -ForegroundColor Yellow
    & $PythonExe -m venv $VenvDir
    Write-Host "[OK] Virtual environment created." -ForegroundColor Green
} else {
    Write-Host "[OK] Virtual environment exists." -ForegroundColor Green
}

# ---- 3. Install dependencies ------------------------------------------------
Write-Host "[..] Installing Python dependencies..." -ForegroundColor Yellow
$Req = Join-Path $ScriptDir 'requirements.txt'
& $VenvPython -m pip install --upgrade pip --quiet
& $VenvPython -m pip install -r $Req --quiet
Write-Host "[OK] Dependencies installed." -ForegroundColor Green

# ---- 4. Register context menu (HKCU, no admin) ------------------------------
$PsScript   = Join-Path $ScriptDir 'rename_menu.ps1'
$Command    = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PsScript`" `"%V`""

$MenuName   = "RenameMenu"
$MenuLabel  = "Rename Files with AI"

$Keys = @(
    "HKCU:\Software\Classes\Directory\shell\$MenuName",
    "HKCU:\Software\Classes\Directory\Background\shell\$MenuName"
)

foreach ($Key in $Keys) {
    if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }
    Set-ItemProperty -Path $Key -Name "(Default)" -Value $MenuLabel
    Set-ItemProperty -Path $Key -Name "Icon" -Value "shell32.dll,71"

    $CmdKey = "$Key\command"
    if (-not (Test-Path $CmdKey)) { New-Item -Path $CmdKey -Force | Out-Null }
    Set-ItemProperty -Path $CmdKey -Name "(Default)" -Value $Command
}

Write-Host "[OK] Context menu registered." -ForegroundColor Green

# ---- 5. Copy config example if no config yet --------------------------------
$ConfigPath   = Join-Path $ScriptDir 'config.json'
$ExamplePath  = Join-Path $ScriptDir 'config.json.example'
if (-not (Test-Path $ConfigPath) -and (Test-Path $ExamplePath)) {
    Copy-Item $ExamplePath $ConfigPath
    Write-Host "[OK] config.json created from example." -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Right-click any folder -> 'Rename Files with AI'" -ForegroundColor Cyan
Write-Host "On first run you will be prompted for your Gemini API key," -ForegroundColor Gray
Write-Host "or leave blank to use Ollama (fully local)." -ForegroundColor Gray
Write-Host ""
