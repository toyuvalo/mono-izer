# create-icon.ps1 -- Generate mono-izer.ico using ImageMagick drawing primitives
# Design: dark rounded bg, one teal waveform (one channel = mono)

param([string]$Dest = $PSScriptRoot)
if (-not $Dest) { $Dest = (Get-Location).Path }

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: ImageMagick not found" -ForegroundColor Red; exit 1
}

$ico = Join-Path $Dest "mono-izer.ico"
$tmp = Join-Path $env:TEMP "monoizericon_build"
New-Item -Path $tmp -ItemType Directory -Force | Out-Null

try {
    # Nine vertical bars, 18 px wide, 8 px apart, centred on y=128.
    $heights = @(40, 84, 132, 176, 208, 176, 132, 84, 40)
    $draw = @()
    for ($i = 0; $i -lt $heights.Count; $i++) {
        $x0 = 21 + $i * 26
        $h = $heights[$i]
        $draw += '-draw', ("roundrectangle {0},{1},{2},{3},9,9" -f $x0, (128 - $h / 2), ($x0 + 18), (128 + $h / 2))
    }

    Write-Host "  Generating 256x256 master..." -ForegroundColor DarkGray
    & magick -size 256x256 xc:none `
        -fill "#161618" -draw "roundrectangle 0,0,255,255,42,42" `
        -fill "#3CD2C8" @draw `
        (Join-Path $tmp "s256.png")

    foreach ($sz in @(48, 32, 16)) {
        & magick (Join-Path $tmp "s256.png") -filter Lanczos -resize "${sz}x${sz}" (Join-Path $tmp "s${sz}.png")
    }

    & magick (Join-Path $tmp "s16.png") (Join-Path $tmp "s32.png") (Join-Path $tmp "s48.png") (Join-Path $tmp "s256.png") $ico
    Write-Host "  Created: $ico" -ForegroundColor Green
} finally {
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
