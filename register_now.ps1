# One-time registry fix — run this, then delete it.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ps1       = "$ScriptDir\rename_menu.ps1"
$MenuName  = "BigBoiRename"
$MenuLabel = "BigBoi Rename"
$CmdFolder = "powershell.exe -ExecutionPolicy Bypass -File `"$ps1`" `"%V`""
$CmdFile   = "powershell.exe -ExecutionPolicy Bypass -File `"$ps1`" `"%1`""

# Folder right-click and folder background (no wildcard — PowerShell provider works fine)
foreach ($base in @(
    "HKCU:\Software\Classes\Directory\shell\$MenuName",
    "HKCU:\Software\Classes\Directory\Background\shell\$MenuName"
)) {
    New-Item -Path $base -Force | Out-Null
    Set-ItemProperty -Path $base -Name "(Default)" -Value $MenuLabel
    Set-ItemProperty -Path $base -Name "Icon"      -Value "shell32.dll,71"
    New-Item -Path "$base\command" -Force | Out-Null
    Set-ItemProperty -Path "$base\command" -Name "(Default)" -Value $CmdFolder
    Write-Host "[OK] $base"
}

# *\shell — use .NET Registry class directly to avoid PowerShell wildcard expansion
# and to preserve quotes in the command value (reg.exe strips them)
$reg = [Microsoft.Win32.Registry]::CurrentUser

$shellKey = $reg.CreateSubKey("Software\Classes\*\shell\$MenuName")
$shellKey.SetValue("", $MenuLabel)
$shellKey.SetValue("Icon", "shell32.dll,71")
$shellKey.Close()

$cmdKey = $reg.CreateSubKey("Software\Classes\*\shell\$MenuName\command")
$cmdKey.SetValue("", $CmdFile)
$cmdKey.Close()

Write-Host "[OK] HKCU\Software\Classes\*\shell\$MenuName"
Write-Host ""
Write-Host "Done. Right-click any file or folder -> 'BigBoi Rename'" -ForegroundColor Cyan
