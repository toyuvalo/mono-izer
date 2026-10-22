# uninstall.ps1 -- Remove the mono-izer context menu entry
# Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$removed = 0
foreach ($ext in '.wav', '.mp3') {
    $regPath = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\MonoIzer"
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
        $removed++
    }
}

# The remembered split prefixes.
if (Test-Path "HKCU:\Software\MonoIzer") { Remove-Item -Path "HKCU:\Software\MonoIzer" -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "Removed $removed registry entries." -ForegroundColor Green
Read-Host "Press Enter to close"
