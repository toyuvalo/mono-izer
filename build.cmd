@echo off
REM build.cmd -- Builds build\MonoIzer.exe and MonoIzer-Install.exe, signed

REM Requires: csc.exe (in-box .NET Framework 4.x) and Inno Setup 6 (ISCC.exe)
REM   winget install JRSoftware.InnoSetup
REM Signing: Azure Artifact Signing, publisher "Yuval Olsha", through the
REM   helper azsign.cmd (signtool + Artifact Signing dlib + az login).
REM   Point AZSIGN at it. Set NOSIGN=1 to build unsigned.

setlocal
set "ROOT=%~dp0"
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

set "ISCC="
for %%P in ("%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "%ProgramFiles%\Inno Setup 6\ISCC.exe") do (
    if not defined ISCC if exist %%P set "ISCC=%%~P"
)
if not defined ISCC (
    echo   ERROR: Inno Setup 6 not found. Install: winget install JRSoftware.InnoSetup
    exit /b 1
)

if not defined NOSIGN if not defined AZSIGN (
    echo   ERROR: set AZSIGN to the path of azsign.cmd, or set NOSIGN=1.
    exit /b 1
)
if not defined NOSIGN if not exist "%AZSIGN%" (
    echo   ERROR: signing helper not found at %AZSIGN%. Set AZSIGN, or NOSIGN=1.
    exit /b 1
)

REM Regenerate the icon if ImageMagick is available.
where magick >nul 2>&1
if %errorlevel%==0 (
    echo Generating icon...
    powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "%ROOT%create-icon.ps1" -Dest "%ROOT%"
)

if not exist "%ROOT%build" mkdir "%ROOT%build"
"%CSC%" /nologo /target:winexe /optimize+ /win32icon:"%ROOT%mono-izer.ico" ^
 /r:Microsoft.CSharp.dll /out:"%ROOT%build\MonoIzer.exe" "%ROOT%launcher\MonoIzerLauncher.cs"
if errorlevel 1 (
    echo   ERROR: launcher compile failed.
    exit /b 1
)

REM Sign a copy of the script, so the source file in git stays unsigned.
copy /y "%ROOT%mono-izer.ps1" "%ROOT%build\mono-izer.ps1" >nul

if defined NOSIGN (
    "%ISCC%" /Q "%ROOT%installer\MonoIzer.iss"
    goto :isccdone
)
call "%AZSIGN%" "%ROOT%build\MonoIzer.exe" "%ROOT%build\mono-izer.ps1"
if errorlevel 1 (
    echo   ERROR: signing failed. Check: az login, and the signer role.
    exit /b 1
)
REM Inno Setup signs the uninstaller and the setup exe with this command.
"%ISCC%" /Q /DSIGN "/Sazsign=$q%COMSPEC%$q /d /c $q$q%AZSIGN%$q $f$q" "%ROOT%installer\MonoIzer.iss"
:isccdone
if errorlevel 1 (
    echo   ERROR: Inno Setup build failed.
    exit /b 1
)

echo.
echo   Built: %ROOT%MonoIzer-Install.exe
echo.
