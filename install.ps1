# BigBoiRename installer — fully local, no API keys needed.
# Safe to re-run at any time. No admin required.
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "BigBoiRename Installer" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Python check --------------------------------------------------------
$PythonExe = $null
foreach ($candidate in @('python', 'python3', 'py')) {
    try {
        $ver = & $candidate --version 2>&1
        if ($ver -match 'Python 3\.([89]|1\d)') { $PythonExe = $candidate; break }
    } catch {}
}
if (-not $PythonExe) {
    Write-Host "ERROR: Python 3.8+ not found. Install from python.org." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Python: $(& $PythonExe --version 2>&1)" -ForegroundColor Green

# ---- 2. Ollama check + install ----------------------------------------------
# Check PATH first, then known install locations
$OllamaExe = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $OllamaExe) {
    foreach ($candidate in @(
        "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe",
        "$env:LOCALAPPDATA\Ollama\ollama.exe",
        "C:\Program Files\Ollama\ollama.exe"
    )) {
        if (Test-Path $candidate) { $OllamaExe = $candidate; break }
    }
}
if (-not $OllamaExe) {
    Write-Host "[..] Ollama not found. Installing via winget..." -ForegroundColor Yellow
    try {
        winget install Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path','User')
        $OllamaExe = Get-Command ollama -ErrorAction SilentlyContinue
        if (-not $OllamaExe) { throw "ollama still not on PATH after install" }
        Write-Host "[OK] Ollama installed." -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Could not auto-install Ollama." -ForegroundColor Red
        Write-Host "       Download manually from https://ollama.com then re-run this script." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[OK] Ollama: $OllamaExe" -ForegroundColor Green
}
$OllamaCmd = if ($OllamaExe -is [System.Management.Automation.CommandInfo]) { $OllamaExe.Source } else { $OllamaExe }

# ---- 3. Model selection -----------------------------------------------------
$modelList = (& $OllamaCmd list 2>&1) -join "`n"
$has1b = $modelList -match 'llama3\.2:1b'
$has3b = $modelList -match 'llama3\.2:3b'

if ($has3b) {
    $OllamaModel = 'llama3.2:3b'
    Write-Host "[OK] Found llama3.2:3b already installed — using it." -ForegroundColor Green
} elseif ($has1b) {
    $OllamaModel = 'llama3.2:1b'
    Write-Host "[OK] Found llama3.2:1b already installed — using it." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  Choose a model to download:" -ForegroundColor Cyan
    Write-Host "  [1] llama3.2:1b  — fast, ~1.3 GB  (recommended)" -ForegroundColor White
    Write-Host "  [2] llama3.2:3b  — better quality, ~2.0 GB" -ForegroundColor White
    Write-Host ""
    # Default to 1b if stdin is not interactive (e.g. run via Claude Code)
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        $choice = Read-Host "  Enter 1 or 2 (default: 1)"
    } else {
        $choice = '1'
        Write-Host "  Non-interactive mode — defaulting to llama3.2:1b" -ForegroundColor DarkGray
    }
    if ($choice -eq '2') {
        $OllamaModel = 'llama3.2:3b'
        $sizeHint    = '~2.0 GB'
    } else {
        $OllamaModel = 'llama3.2:1b'
        $sizeHint    = '~1.3 GB'
    }
    Write-Host "[..] Pulling $OllamaModel ($sizeHint, one-time download)..." -ForegroundColor Yellow
    & $OllamaCmd pull $OllamaModel
    Write-Host "[OK] Model ready." -ForegroundColor Green
}

# ---- 4. Ensure Ollama server is running ------------------------------------
Write-Host "[..] Starting Ollama server..." -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri 'http://localhost:11434' -TimeoutSec 3 -ErrorAction Stop | Out-Null
    Write-Host "[OK] Ollama server already running." -ForegroundColor Green
} catch {
    Start-Process -FilePath $OllamaCmd -ArgumentList 'serve' -WindowStyle Hidden
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
$PsScript  = Join-Path $ScriptDir 'rename_menu.ps1'
$MenuName  = "BigBoiRename"
$MenuLabel = "BigBoi Rename"

# Remove old keys (RenameMenu was the previous name — clean up if present)
$OldKeys = @(
    "HKCU:\Software\Classes\Directory\shell\RenameMenu",
    "HKCU:\Software\Classes\Directory\Background\shell\RenameMenu",
    "HKCU:\Software\Classes\*\shell\RenameMenu"
)
foreach ($Key in $OldKeys) {
    if (Test-Path $Key) {
        Remove-Item -Path $Key -Recurse -Force
        Write-Host "[OK] Removed old key: $Key" -ForegroundColor DarkGray
    }
}

# Remove existing BigBoiRename keys before re-registering (idempotent)
$CurrentKeys = @(
    "HKCU:\Software\Classes\Directory\shell\$MenuName",
    "HKCU:\Software\Classes\Directory\Background\shell\$MenuName",
    "HKCU:\Software\Classes\*\shell\$MenuName"
)
foreach ($Key in $CurrentKeys) {
    if (Test-Path $Key) { Remove-Item -Path $Key -Recurse -Force }
}

# Folder right-click + folder background use %V (the folder path)
$CmdFolder = "powershell.exe -ExecutionPolicy Bypass -File `"$PsScript`" `"%V`""
# File right-click uses %1 (the file path)
$CmdFile   = "powershell.exe -ExecutionPolicy Bypass -File `"$PsScript`" `"%1`""

# Folder keys — PowerShell registry provider works fine (no wildcards)
foreach ($base in @(
    "HKCU:\Software\Classes\Directory\shell\$MenuName",
    "HKCU:\Software\Classes\Directory\Background\shell\$MenuName"
)) {
    New-Item -Path $base -Force | Out-Null
    Set-ItemProperty -Path $base -Name "(Default)" -Value $MenuLabel
    Set-ItemProperty -Path $base -Name "Icon"      -Value "shell32.dll,71"
    New-Item -Path "$base\command" -Force | Out-Null
    Set-ItemProperty -Path "$base\command" -Name "(Default)" -Value $CmdFolder
}

# *\shell key — must use .NET Registry API directly.
# PowerShell's provider wildcard-expands * and reg.exe strips quotes from values.
$reg = [Microsoft.Win32.Registry]::CurrentUser
$shellKey = $reg.CreateSubKey("Software\Classes\*\shell\$MenuName")
$shellKey.SetValue("", $MenuLabel)
$shellKey.SetValue("Icon", "shell32.dll,71")
$shellKey.Close()
$cmdKey = $reg.CreateSubKey("Software\Classes\*\shell\$MenuName\command")
$cmdKey.SetValue("", $CmdFile)
$cmdKey.Close()

Write-Host "[OK] Context menu registered (folders + all file types)." -ForegroundColor Green

# ---- 8. Write config.json with the chosen model ----------------------------
$ConfigPath  = Join-Path $ScriptDir 'config.json'
$ExamplePath = Join-Path $ScriptDir 'config.json.example'

if (-not (Test-Path $ConfigPath)) {
    Copy-Item $ExamplePath $ConfigPath
}

try {
    $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $cfg.ollama_model = $OllamaModel
    $cfg | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "[OK] config.json: ollama_model = $OllamaModel" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not update config.json: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "All done! Right-click any file or folder -> 'BigBoi Rename'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Model:  $OllamaModel  (fully local, no internet after this)" -ForegroundColor Gray
Write-Host "Config: $ConfigPath" -ForegroundColor Gray
Write-Host ""
