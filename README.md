<img src="screenshots/icon.png" width="72" align="right" alt="mono-izer icon">

# mono-izer

Right-click a stereo `.wav` or `.mp3` on Windows → **mono-izer** → a mono copy appears next to it.

> **Platform:** Windows only. It uses Windows shell integration and ffmpeg.

## What it does

| Before: stereo (left + right) | After: mono (left only) |
|---|---|
| ![Stereo waveform, left channel teal, right channel orange](screenshots/before-stereo.png) | ![Mono waveform, the left channel only](screenshots/after-mono.png) |

- **Keeps the left channel and removes the right.** It does not mix the two channels, so the level does not change.
- **Nothing else changes.** Sample rate and bit depth stay the same. A 48 kHz 24-bit WAV becomes a 48 kHz 24-bit mono WAV. Tags are copied.
- **WAV is lossless.** The output uses the same PCM format as the source, so the mono file is bit-for-bit identical to the source's left channel.
- **MP3 is re-encoded once.** An MP3 cannot be edited without re-encoding. The output keeps the source bitrate, sample rate, tags and cover art.
- **The original is never modified.** The output is `<name>_mono.wav` or `<name>_mono.mp3`. If that name exists, it uses `_mono_2`, `_mono_3` and so on. Nothing is overwritten.
- **Mono files are skipped.**
- **Many files at once.** Select any number of files and right-click once. They are converted one at a time, at low priority, so a large batch does not slow down other work.
- **Errors** appear in one dialog at the end of the batch. Each result is written to `mono-izer.log` in the install folder.

## Install

**One click:** Download **[MonoIzer-Install.exe](../../releases/latest/download/MonoIzer-Install.exe)** and run it. No admin required. The installer (Inno Setup, per-user) is code-signed by Yuval Olsha, runs no scripts, and adds a normal uninstall entry in Settings > Apps.

**Manual:** Clone the repo, right-click `install.ps1` → Run with PowerShell. It compiles the launcher with the in-box C# compiler and registers the menu entry.

## Requirements

- ffmpeg and ffprobe — [gyan.dev/ffmpeg/builds](https://www.gyan.dev/ffmpeg/builds/)

The installer handles this. A copy already on your PATH is used as-is. If ffmpeg is missing, the installer downloads it (about 35 MB) from [GyanD/codexffmpeg](https://github.com/GyanD/codexffmpeg) (gyan.dev's own mirror), checks its SHA-256, puts it in `%LOCALAPPDATA%\Programs\DVLCE\ffmpeg` and adds that folder to your user PATH. [FFmpeg Convert](https://github.com/toyuvalo/ffmpeg-context-menu), [Shrink Menu](https://github.com/toyuvalo/shrink-menu) and [Doc Convert](https://github.com/toyuvalo/doc-convert-menu) use the same shared folder, so ffmpeg is downloaded once. Uninstalling removes the shared copy only when no other of these tools still needs it.

## How it works

`MonoIzer.exe` is a small compiled launcher. Explorer starts one launcher per selected file; the first one collects the whole selection and starts `mono-izer.ps1` once with the list. The script runs this for each file:

```
ffmpeg -i in.wav -map 0:a:0 -map_metadata 0 -af channelmap=map=0:channel_layout=mono -c:a <source codec> in_mono.wav
```

`channelmap` copies channel 0 (left) without converting the sample format.

## Uninstall

Settings > Apps > mono-izer > Uninstall. For a manual install, run `uninstall.ps1` with PowerShell.

## Build the exe yourself

```cmd
set NOSIGN=1
build.cmd
```

Requires Inno Setup 6 (`winget install JRSoftware.InnoSetup`). The launcher is compiled with the in-box C# compiler. Release builds are signed with Azure Artifact Signing through an `azsign.cmd` helper (set `AZSIGN` to its path); `NOSIGN=1` builds unsigned. ImageMagick on PATH regenerates the icon.

## More tools like this

Built by [dvlce.ca](https://dvlce.ca) — see [webdev.dvlce.ca](https://webdev.dvlce.ca) for the full project showcase.

## License

MIT with [Commons Clause](https://commonsclause.com/) — free to use, modify, and share. Commercial resale not permitted.
