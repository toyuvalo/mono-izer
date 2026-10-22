# install.ps1 -- Register the mono-izer context menu entry (no admin required)
# Run: powershell -ExecutionPolicy Bypass -File install.ps1
# The one-click installer (MonoIzer-Install.exe) does the same without PowerShell.

$launcherPath = Join-Path $PSScriptRoot "build\MonoIzer.exe"
$scriptPath   = Join-Path $PSScriptRoot "mono-izer.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: mono-izer.ps1 not found in $PSScriptRoot" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $launcherPath)) {
    # Compile the launcher with the in-box .NET Framework compiler (no extra install).
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
    New-Item -ItemType Directory -Path (Split-Path $launcherPath) -Force | Out-Null
    & $csc /nologo /target:winexe /optimize+ "/win32icon:$(Join-Path $PSScriptRoot 'mono-izer.ico')" /r:Microsoft.CSharp.dll "/out:$launcherPath" (Join-Path $PSScriptRoot "launcher\MonoIzerLauncher.cs")
    if (-not (Test-Path $launcherPath)) {
        Write-Host "ERROR: could not build $launcherPath" -ForegroundColor Red
        exit 1
    }
    # The launcher starts the script from its own folder.
    Copy-Item $scriptPath (Split-Path $launcherPath) -Force
}

Write-Host "mono-izer -- Installer" -ForegroundColor Yellow
Write-Host ""

if ((Get-Command ffmpeg -ErrorAction SilentlyContinue) -and (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host "  [OK] ffmpeg and ffprobe found" -ForegroundColor Green
} else {
    Write-Host "  [!!] ffmpeg / ffprobe NOT found -- mono-izer will not work until they are on PATH" -ForegroundColor Yellow
    Write-Host "       Install: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor DarkGray
}

$icoPath  = Join-Path $PSScriptRoot "mono-izer.ico"
$menuIcon = if (Test-Path $icoPath) { "$icoPath,0" } else { "shell32.dll,168" }
$cmd      = "`"$launcherPath`" `"%1`""

foreach ($ext in '.wav', '.mp3') {
    $regPath = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\MonoIzer"
    if (Test-Path $regPath) { Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "(Default)"        -Value "mono-izer"
    Set-ItemProperty -Path $regPath -Name "Icon"             -Value $menuIcon
    Set-ItemProperty -Path $regPath -Name "MultiSelectModel" -Value "Player"
    New-Item -Path "$regPath\command" -Force | Out-Null
    Set-ItemProperty -Path "$regPath\command" -Name "(Default)" -Value $cmd
}

Write-Host "  Registered .wav and .mp3" -ForegroundColor Green
Write-Host ""
Write-Host "Right-click a stereo .wav or .mp3 and pick 'mono-izer'." -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to close"
