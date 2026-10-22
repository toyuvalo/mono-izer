# mono-izer.ps1 -- stereo WAV/MP3 to mono, left channel only (v1.0.0)
# Writes <name>_mono.<ext> next to each file. The original is never modified.
# The left channel is kept as-is: no downmix, no level change. WAV keeps its
# PCM codec (bit depth) and sample rate, so the result is lossless. MP3 must be
# re-encoded; it keeps the source bitrate, sample rate, tags and cover art.
# Started by MonoIzer.exe (right-click) with -ListFile, or by hand with -Path.
param(
    [string]$ListFile,
    [string[]]$Path
)

# Continue, not Stop: under Stop, Windows PowerShell 5.1 turns any ffmpeg stderr line
# into a terminating error before the half-written output can be removed.
$ErrorActionPreference = 'Continue'
$Version = '1.0.0'
$LogFile = Join-Path $PSScriptRoot 'mono-izer.log'

function Log($msg) {
    try { Add-Content -LiteralPath $LogFile -Encoding UTF8 -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) } catch { }
}

$files = @()
if ($ListFile) {
    $files += Get-Content -LiteralPath $ListFile -Encoding UTF8 | Where-Object { $_ -ne '' }
    Remove-Item -LiteralPath $ListFile -ErrorAction SilentlyContinue
}
if ($Path) { $files += $Path }
if ($files.Count -eq 0) { exit 0 }

# Low priority: a batch of long recordings never slows down the foreground app.
[System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal'

# One batch at a time, even when two right-clicks overlap.
$mutex = New-Object System.Threading.Mutex($false, 'Local\mono-izer')
[void]$mutex.WaitOne()

function Convert-ToMono([string]$in) {
    if (-not (Test-Path -LiteralPath $in)) { throw 'File not found.' }
    $ext = [IO.Path]::GetExtension($in).ToLower()
    if ($ext -notin '.wav', '.mp3') { throw 'Only .wav and .mp3 files are supported.' }

    $json = & ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,channels,bit_rate,sample_rate -of json -- "$in"
    if ($LASTEXITCODE -ne 0) { throw 'ffprobe could not read the file.' }
    $s = ($json | ConvertFrom-Json).streams | Select-Object -First 1
    if (-not $s) { throw 'No audio stream found.' }
    if ([int]$s.channels -eq 1) { Log "SKIP $in : already mono"; return }

    $dir = [IO.Path]::GetDirectoryName($in)
    $base = [IO.Path]::GetFileNameWithoutExtension($in)
    $out = Join-Path $dir "$base`_mono$ext"
    $n = 2
    while (Test-Path -LiteralPath $out) { $out = Join-Path $dir "$base`_mono_$n$ext"; $n++ }

    # channelmap takes channel 0 (left) and does not convert the sample format.
    $af = 'channelmap=map=0:channel_layout=mono'
    if ($ext -eq '.wav') {
        # Same PCM codec as the source (e.g. pcm_s24le): bit-exact left channel.
        $ffArgs = @('-map', '0:a:0', '-map_metadata', '0', '-af', $af, '-c:a', $s.codec_name)
    } else {
        $br = if ($s.bit_rate) { [int]$s.bit_rate } else { 320000 }
        $ffArgs = @('-map', '0:a:0', '-map', '0:v?', '-map_metadata', '0', '-af', $af,
                    '-c:a', 'libmp3lame', '-b:a', "$br", '-c:v', 'copy', '-id3v2_version', '3')
    }

    $err = & ffmpeg -hide_banner -nostdin -v error -i "$in" @ffArgs -- "$out" 2>&1
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out }
        throw "ffmpeg failed: $err"
    }
    Log "OK   $in -> $out ($($s.codec_name), $($s.sample_rate) Hz, $($s.channels)ch -> 1ch)"
}

$failed = @()
try {
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue) -or -not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
        $failed += 'ffmpeg and ffprobe must be on the PATH. Run the installer again, or install ffmpeg from https://www.gyan.dev/ffmpeg/builds/'
    } else {
        foreach ($f in $files) {
            try { Convert-ToMono $f }
            catch { Log "FAIL $f : $($_.Exception.Message)"; $failed += "$([IO.Path]::GetFileName($f)): $($_.Exception.Message)" }
        }
    }
}
finally {
    $mutex.ReleaseMutex()
}

if ($failed.Count -gt 0) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(($failed -join "`n`n"), "mono-izer v$Version", 'OK', 'Error') | Out-Null
    exit 1
}
