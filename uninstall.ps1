# RenameMenu uninstaller — removes context menu entries from HKCU
$MenuName = "RenameMenu"

$Keys = @(
    "HKCU:\Software\Classes\Directory\shell\$MenuName",
    "HKCU:\Software\Classes\Directory\Background\shell\$MenuName"
)

foreach ($Key in $Keys) {
    if (Test-Path $Key) {
        Remove-Item -Path $Key -Recurse -Force
        Write-Host "[OK] Removed: $Key" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "RenameMenu context menu removed." -ForegroundColor Cyan
Write-Host "Your config.json and .venv folder were left intact." -ForegroundColor Gray
Write-Host "Delete the RenameMenu folder manually to fully remove the tool." -ForegroundColor Gray
