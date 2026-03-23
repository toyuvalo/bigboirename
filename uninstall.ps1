# BigBoiRename uninstaller — removes all context menu entries from HKCU
$MenuName = "BigBoiRename"

$Keys = @(
    "HKCU:\Software\Classes\Directory\shell\$MenuName",
    "HKCU:\Software\Classes\Directory\Background\shell\$MenuName",
    "HKCU:\Software\Classes\*\shell\$MenuName"
)

foreach ($Key in $Keys) {
    if (Test-Path $Key) {
        Remove-Item -Path $Key -Recurse -Force
        Write-Host "[OK] Removed: $Key" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "BigBoiRename context menu removed." -ForegroundColor Cyan
Write-Host "Your config.json and .venv folder were left intact." -ForegroundColor Gray
Write-Host "Delete the folder manually to fully remove the tool." -ForegroundColor Gray
