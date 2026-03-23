# BigBoiRename launcher — called by Windows Explorer context menu
param([string]$Path)

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VenvPython = Join-Path $ScriptDir '.venv\Scripts\python.exe'
$MainScript = Join-Path $ScriptDir 'rename_menu.py'
$LogFile    = Join-Path $ScriptDir 'error.log'

function Show-Error($msg) {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.MessageBox]::Show(
        $msg, "BigBoiRename Error", "OK", "Error"
    ) | Out-Null
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
}

try {
    if (-not (Test-Path $VenvPython)) {
        Show-Error "BigBoiRename is not set up.`n`nRun install.ps1 first:`n$ScriptDir\install.ps1"
        exit 1
    }
    if (-not $Path) {
        Show-Error "No path received from Explorer. Try right-clicking again."
        exit 1
    }

    $proc = Start-Process -FilePath $VenvPython `
        -ArgumentList "`"$MainScript`" `"$Path`"" `
        -NoNewWindow -PassThru -Wait

    if ($proc.ExitCode -ne 0) {
        $log = if (Test-Path $LogFile) { "`n`nLast error: $(Get-Content $LogFile -Tail 3 | Out-String)" } else { "" }
        Show-Error "BigBoiRename exited with an error (code $($proc.ExitCode)).$log"
    }
} catch {
    Show-Error "BigBoiRename failed to launch:`n$($_.Exception.Message)"
}
