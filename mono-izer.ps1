# mono-izer.ps1 -- stereo WAV/MP3 to mono, or split into two mono files (v1.1.0)
# Mode Mono  (default): writes <name>_mono.<ext>, the LEFT channel only.
# Mode Split: asks once per batch for a left and a right prefix, then writes
#   <leftprefix><name>.<ext> (left channel) and <rightprefix><name>.<ext> (right).
# The original is never modified. A channel is kept as-is: no downmix, no level
# change. WAV keeps its PCM codec (bit depth) and sample rate, so the result is
# lossless. MP3 must be re-encoded; it keeps the source bitrate, sample rate, tags
# and cover art.
# Started by MonoIzer.exe (right-click) with -ListFile, or by hand with -Path.
# -LeftPrefix / -RightPrefix skip the split dialog.
param(
    [string]$ListFile,
    [string[]]$Path,
    [ValidateSet('Mono', 'Split')][string]$Mode = 'Mono',
    [string]$LeftPrefix,
    [string]$RightPrefix
)

# Continue, not Stop: under Stop, Windows PowerShell 5.1 turns any ffmpeg stderr line
# into a terminating error before the half-written output can be removed.
$ErrorActionPreference = 'Continue'
$Version = '1.1.0'
$LogFile = Join-Path $PSScriptRoot 'mono-izer.log'
$SettingsKey = 'HKCU:\Software\MonoIzer'

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

# Returns an error message, or $null when the two prefixes are usable.
function Test-Prefixes([string]$left, [string]$right) {
    if ($left -eq '' -or $right -eq '') { return 'Enter a prefix for both sides.' }
    if ($left -eq $right) { return 'The two prefixes must be different, or the files would have the same name.' }
    $bad = [IO.Path]::GetInvalidFileNameChars()
    foreach ($p in $left, $right) {
        if ($p.IndexOfAny($bad) -ge 0) { return "A prefix cannot contain any of these characters:  \ / : * ? `" < > |" }
    }
    return $null
}

# One dialog for the whole batch. Returns @(left, right), or $null on Cancel.
function Show-PrefixDialog([string]$exampleName) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $left = 'L_'; $right = 'R_'
    try {
        $saved = Get-ItemProperty -LiteralPath $SettingsKey -ErrorAction Stop
        if ($saved.LeftPrefix) { $left = $saved.LeftPrefix }
        if ($saved.RightPrefix) { $right = $saved.RightPrefix }
    } catch { }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "mono-izer v$Version - Split L / R"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false; $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(380, 196)
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.TopMost = $true
    $form.StartPosition = 'CenterScreen'
    # Automated tests open the dialog off-screen: MONOIZER_DIALOG_POS = "x,y".
    if ($env:MONOIZER_DIALOG_POS -match '^(-?\d+),(-?\d+)$') {
        $form.StartPosition = 'Manual'; $form.TopMost = $false
        $form.Location = New-Object System.Drawing.Point([int]$Matches[1], [int]$Matches[2])
    }
    $icon = Join-Path $PSScriptRoot 'mono-izer.ico'
    if (Test-Path -LiteralPath $icon) { $form.Icon = New-Object System.Drawing.Icon($icon) }

    function Add-Row($label, $value, $y) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $label; $l.Location = New-Object System.Drawing.Point(16, ($y + 3)); $l.AutoSize = $true
        $t = New-Object System.Windows.Forms.TextBox
        $t.Text = $value; $t.Location = New-Object System.Drawing.Point(120, $y); $t.Width = 244
        $form.Controls.AddRange(@($l, $t))
        return $t
    }
    $leftBox = Add-Row 'Left prefix' $left 16
    $rightBox = Add-Row 'Right prefix' $right 48

    $preview = New-Object System.Windows.Forms.Label
    $preview.Location = New-Object System.Drawing.Point(16, 82); $preview.Size = New-Object System.Drawing.Size(348, 36)
    $preview.ForeColor = [System.Drawing.Color]::DimGray
    $err = New-Object System.Windows.Forms.Label
    $err.Location = New-Object System.Drawing.Point(16, 120); $err.Size = New-Object System.Drawing.Size(348, 32)
    $err.ForeColor = [System.Drawing.Color]::Firebrick

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Split'; $ok.Location = New-Object System.Drawing.Point(208, 158); $ok.Width = 75
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'; $cancel.Location = New-Object System.Drawing.Point(289, 158); $cancel.Width = 75
    $cancel.DialogResult = 'Cancel'
    $form.AcceptButton = $ok; $form.CancelButton = $cancel
    $form.Controls.AddRange(@($preview, $err, $ok, $cancel))

    $update = {
        $preview.Text = "Left  ->  $($leftBox.Text)$exampleName`nRight  ->  $($rightBox.Text)$exampleName"
        $err.Text = ''
    }
    $leftBox.Add_TextChanged($update); $rightBox.Add_TextChanged($update)
    & $update
    $ok.Add_Click({
        $msg = Test-Prefixes $leftBox.Text $rightBox.Text
        if ($msg) { $err.Text = $msg } else { $form.DialogResult = 'OK'; $form.Close() }
    })
    $form.Add_Shown({ $form.Activate(); $leftBox.Focus() })

    if ($form.ShowDialog() -ne 'OK') { return $null }
    $result = @($leftBox.Text, $rightBox.Text)
    try {
        New-Item -Path $SettingsKey -Force | Out-Null
        Set-ItemProperty -LiteralPath $SettingsKey -Name LeftPrefix -Value $result[0]
        Set-ItemProperty -LiteralPath $SettingsKey -Name RightPrefix -Value $result[1]
    } catch { }
    return $result
}

if ($Mode -eq 'Split') {
    if ($PSBoundParameters.ContainsKey('LeftPrefix') -and $PSBoundParameters.ContainsKey('RightPrefix')) {
        $msg = Test-Prefixes $LeftPrefix $RightPrefix
        if ($msg) { Log "FAIL prefixes '$LeftPrefix' / '$RightPrefix' : $msg"; Write-Error $msg; exit 2 }
    } else {
        $pair = Show-PrefixDialog ([IO.Path]::GetFileName($files[0]))
        if (-not $pair) { Log "CANCEL split of $($files.Count) file(s)"; exit 0 }
        $LeftPrefix, $RightPrefix = $pair
    }
}

# Low priority: a batch of long recordings never slows down the foreground app.
[System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal'

# One batch at a time, even when two right-clicks overlap.
$mutex = New-Object System.Threading.Mutex($false, 'Local\mono-izer')
[void]$mutex.WaitOne()

# Reads the first audio stream. Returns $null for a mono file.
function Get-Stereo([string]$in) {
    if (-not (Test-Path -LiteralPath $in)) { throw 'File not found.' }
    $ext = [IO.Path]::GetExtension($in).ToLower()
    if ($ext -notin '.wav', '.mp3') { throw 'Only .wav and .mp3 files are supported.' }

    $json = & ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,channels,bit_rate,sample_rate -of json -- "$in"
    if ($LASTEXITCODE -ne 0) { throw 'ffprobe could not read the file.' }
    $s = ($json | ConvertFrom-Json).streams | Select-Object -First 1
    if (-not $s) { throw 'No audio stream found.' }
    if ([int]$s.channels -eq 1) { Log "SKIP $in : already mono"; return $null }
    return $s
}

# First free name: <dir>\<stem><ext>, then <stem>_2<ext>, <stem>_3<ext> ...
function Get-FreeName([string]$dir, [string]$stem, [string]$ext) {
    $out = Join-Path $dir "$stem$ext"
    $n = 2
    while (Test-Path -LiteralPath $out) { $out = Join-Path $dir "$stem`_$n$ext"; $n++ }
    return $out
}

# Writes one channel (0 = left, 1 = right) of $in to $out as a mono file.
function Write-Channel([string]$in, $s, [int]$channel, [string]$out) {
    # channelmap copies one channel and does not convert the sample format.
    $af = "channelmap=map=$($channel):channel_layout=mono"
    if ([IO.Path]::GetExtension($in).ToLower() -eq '.wav') {
        # Same PCM codec as the source (e.g. pcm_s24le): bit-exact channel.
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
}

function Convert-ToMono([string]$in) {
    $s = Get-Stereo $in
    if (-not $s) { return }
    $ext = [IO.Path]::GetExtension($in)
    $out = Get-FreeName ([IO.Path]::GetDirectoryName($in)) "$([IO.Path]::GetFileNameWithoutExtension($in))_mono" $ext
    Write-Channel $in $s 0 $out
    Log "OK   $in -> $out ($($s.codec_name), $($s.sample_rate) Hz, $($s.channels)ch -> 1ch)"
}

function Split-Channels([string]$in) {
    $s = Get-Stereo $in
    if (-not $s) { return }
    $dir = [IO.Path]::GetDirectoryName($in)
    $base = [IO.Path]::GetFileNameWithoutExtension($in)
    $ext = [IO.Path]::GetExtension($in)
    $leftOut = Get-FreeName $dir "$LeftPrefix$base" $ext
    Write-Channel $in $s 0 $leftOut
    $rightOut = Get-FreeName $dir "$RightPrefix$base" $ext
    try { Write-Channel $in $s 1 $rightOut }
    catch {
        # Both files or neither: a lone left file looks like a finished split.
        Remove-Item -LiteralPath $leftOut -ErrorAction SilentlyContinue
        throw
    }
    Log "OK   $in -> $leftOut + $rightOut ($($s.codec_name), $($s.sample_rate) Hz, split)"
}

$failed = @()
try {
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue) -or -not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
        $failed += 'ffmpeg and ffprobe must be on the PATH. Run the installer again, or install ffmpeg from https://www.gyan.dev/ffmpeg/builds/'
    } else {
        foreach ($f in $files) {
            try { if ($Mode -eq 'Split') { Split-Channels $f } else { Convert-ToMono $f } }
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
