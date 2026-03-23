# RenameMenu installer — fully local, no API keys needed.
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

# ---- 3. Model selection -----------------------------------------------------
$modelList = (& ollama list 2>&1) -join "`n"

$has1b = $modelList -match 'llama3\.2:1b'
$has3b = $modelList -match 'llama3\.2:3b'

if ($has3b) {
    # 3b already installed — use it, no prompt needed
    $OllamaModel = 'llama3.2:3b'
    Write-Host "[OK] Found llama3.2:3b already installed — using it." -ForegroundColor Green
} elseif ($has1b) {
    # 1b already installed — use it, no prompt needed
    $OllamaModel = 'llama3.2:1b'
    Write-Host "[OK] Found llama3.2:1b already installed — using it." -ForegroundColor Green
} else {
    # Neither present — ask which to pull
    Write-Host ""
    Write-Host "  Choose a model to download:" -ForegroundColor Cyan
    Write-Host "  [1] llama3.2:1b  — fast, ~1.3 GB  (recommended)" -ForegroundColor White
    Write-Host "  [2] llama3.2:3b  — better quality, ~2.0 GB" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "  Enter 1 or 2 (default: 1)"
    if ($choice -eq '2') {
        $OllamaModel = 'llama3.2:3b'
        $sizeHint    = '~2.0 GB'
    } else {
        $OllamaModel = 'llama3.2:1b'
        $sizeHint    = '~1.3 GB'
    }
    Write-Host "[..] Pulling $OllamaModel ($sizeHint, one-time download)..." -ForegroundColor Yellow
    & ollama pull $OllamaModel
    Write-Host "[OK] Model ready." -ForegroundColor Green
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

# ---- 8. Write config.json with the chosen model ----------------------------
$ConfigPath  = Join-Path $ScriptDir 'config.json'
$ExamplePath = Join-Path $ScriptDir 'config.json.example'

if (-not (Test-Path $ConfigPath)) {
    Copy-Item $ExamplePath $ConfigPath
}

# Update ollama_model to whatever was selected/detected
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$cfg.ollama_model = $OllamaModel
$cfg | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding UTF8
Write-Host "[OK] config.json: ollama_model = $OllamaModel" -ForegroundColor Green

Write-Host ""
Write-Host "All done! Right-click any folder -> 'Rename Files with AI'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Model:  $OllamaModel  (fully local, no API key needed)" -ForegroundColor Gray
Write-Host "Config: $ConfigPath" -ForegroundColor Gray
Write-Host ""
