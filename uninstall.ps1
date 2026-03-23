# BigBoiRename uninstaller
$MenuName = "BigBoiRename"

# Folder keys — PowerShell provider is fine here
foreach ($k in @(
    "HKCU:\Software\Classes\Directory\shell\$MenuName",
    "HKCU:\Software\Classes\Directory\Background\shell\$MenuName"
)) {
    if (Test-Path $k) {
        Remove-Item -Path $k -Recurse -Force
        Write-Host "[OK] Removed: $k" -ForegroundColor Green
    }
}

# *\shell key — .NET Registry API to avoid wildcard expansion
$reg = [Microsoft.Win32.Registry]::CurrentUser
try {
    $reg.DeleteSubKeyTree("Software\Classes\*\shell\$MenuName", $false)
    Write-Host "[OK] Removed: HKCU\Software\Classes\*\shell\$MenuName" -ForegroundColor Green
} catch {}

Write-Host ""
Write-Host "BigBoiRename context menu removed." -ForegroundColor Cyan
Write-Host "Your config.json and .venv are untouched. Delete the folder to fully remove." -ForegroundColor Gray
