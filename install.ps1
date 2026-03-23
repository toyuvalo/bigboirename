# RenameMenu installer — fully local, no API keys needed.
# Registers right-click context menu on folders. No admin required.
# Run once after cloning: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = 'Stop'
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OllamaModel = 'llama3.2:1b'   # ~1.3 GB — change to llama3.2:3b for better quality

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
Write-Host "[OK] Python: $($PythonExe)" -ForegroundColor Green

# ---- 2. Ollama check + install ----------------------------------------------
$OllamaExe = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $OllamaExe) {
    Write-Host "[..] Ollama not found. Installing via winget..." -ForegroundColor Yellow
    try {
        winget install Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path','User')
        $OllamaExe = Get-Command ollama -ErrorAction SilentlyContinue
        if (-not $OllamaExe) { throw "ollama still not on PATH after install" }
        Write-Host "[OK] Ollama installed." -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Could not install Ollama automatically." -ForegroundColor Red
        Write-Host "       Download manually from https://ollama.com and re-run this script." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[OK] Ollama: $($OllamaExe.Source)" -ForegroundColor Green
}

# ---- 3. Pull model if not already present -----------------------------------
Write-Host "[..] Checking for model '$OllamaModel'..." -ForegroundColor Yellow
$modelList = & ollama list 2>&1
if ($modelList -notmatch [regex]::Escape($OllamaModel.Split(':')[0])) {
    Write-Host "[..] Pulling $OllamaModel (~1.3 GB, one-time download)..." -ForegroundColor Yellow
    & ollama pull $OllamaModel
    Write-Host "[OK] Model ready." -ForegroundColor Green
} else {
    Write-Host "[OK] Model '$OllamaModel' already present." -ForegroundColor Green
}

# ---- 4. Ensure Ollama server is running ------------------------------------
Write-Host "[..] Starting Ollama server..." -ForegroundColor Yellow
try {
    $resp = Invoke-RestMethod -Uri 'http://localhost:11434' -TimeoutSec 3 -ErrorAction Stop
    Write-Host "[OK] Ollama server already running." -ForegroundColor Green
} catch {
    Start-Process -FilePath 'ollama' -ArgumentList 'serve' -WindowStyle Hidden
    Start-Sleep -Seconds 2
    Write-Host "[OK] Ollama server started." -ForegroundColor Green
}

# ---- 5. Create virtualenv ---------------------------------------------------
$VenvDir    = Join-Path $ScriptDir '.venv'
$VenvPython = Join-Path $VenvDir 'Scripts\python.exe'

if (-not (Test-Path $VenvPython)) {
    Write-Host "[..] Creating virtual environment..." -ForegroundColor Yellow
    & $PythonExe -m venv $VenvDir
    Write-Host "[OK] Virtual environment created." -ForegroundColor Green
} else {
    Write-Host "[OK] Virtual environment exists." -ForegroundColor Green
}

# ---- 6. Install Python dependencies ----------------------------------------
Write-Host "[..] Installing Python dependencies..." -ForegroundColor Yellow
& $VenvPython -m pip install --upgrade pip --quiet
& $VenvPython -m pip install -r (Join-Path $ScriptDir 'requirements.txt') --quiet
Write-Host "[OK] Dependencies installed." -ForegroundColor Green

# ---- 7. Register context menu (HKCU, no admin) ------------------------------
$PsScript = Join-Path $ScriptDir 'rename_menu.ps1'
$Command  = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PsScript`" `"%V`""
$MenuName = "RenameMenu"
$MenuLabel = "Rename Files with AI"

$Keys = @(
    "HKCU:\Software\Classes\Directory\shell\$MenuName",
    "HKCU:\Software\Classes\Directory\Background\shell\$MenuName"
)
foreach ($Key in $Keys) {
    if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }
    Set-ItemProperty -Path $Key -Name "(Default)" -Value $MenuLabel
    Set-ItemProperty -Path $Key -Name "Icon"      -Value "shell32.dll,71"
    $CmdKey = "$Key\command"
    if (-not (Test-Path $CmdKey)) { New-Item -Path $CmdKey -Force | Out-Null }
    Set-ItemProperty -Path $CmdKey -Name "(Default)" -Value $Command
}
Write-Host "[OK] Context menu registered." -ForegroundColor Green

# ---- 8. Create config.json from example if not present ---------------------
$ConfigPath  = Join-Path $ScriptDir 'config.json'
$ExamplePath = Join-Path $ScriptDir 'config.json.example'
if (-not (Test-Path $ConfigPath) -and (Test-Path $ExamplePath)) {
    Copy-Item $ExamplePath $ConfigPath
    Write-Host "[OK] config.json created." -ForegroundColor Green
}

Write-Host ""
Write-Host "All done! Right-click any folder -> 'Rename Files with AI'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Model:  $OllamaModel  (fully local, no API key needed)" -ForegroundColor Gray
Write-Host "Config: $ConfigPath" -ForegroundColor Gray
Write-Host ""
