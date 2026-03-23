# Re-register BigBoiRename context menu using launcher.vbs (no console flash)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$vbs       = "$ScriptDir\launcher.vbs"
$MenuName  = "BigBoiRename"
$MenuLabel = "BigBoi Rename"
$CmdAny    = "wscript.exe `"$vbs`" `"%1`""   # files + folder %1
$CmdFolder = "wscript.exe `"$vbs`" `"%V`""   # folder right-click / background %V

# Folder keys
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

# *\shell — .NET Registry API (PowerShell wildcards + reg.exe both break this key)
$reg = [Microsoft.Win32.Registry]::CurrentUser

$shellKey = $reg.CreateSubKey("Software\Classes\*\shell\$MenuName")
$shellKey.SetValue("", $MenuLabel)
$shellKey.SetValue("Icon", "shell32.dll,71")
$shellKey.Close()

$cmdKey = $reg.CreateSubKey("Software\Classes\*\shell\$MenuName\command")
$cmdKey.SetValue("", $CmdAny)
$cmdKey.Close()

Write-Host "[OK] HKCU\Software\Classes\*\shell\$MenuName"
Write-Host ""
Write-Host "Done. Right-click any file or folder -> 'BigBoi Rename'" -ForegroundColor Cyan
