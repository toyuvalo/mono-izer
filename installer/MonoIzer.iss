; MonoIzer.iss -- Inno Setup script for MonoIzer-Install.exe (v1.0.0)
; Runs no scripts: it copies files and writes the HKCU context-menu keys itself.
; When ffmpeg is not on the PATH, it downloads it (dvlce-deps.iss).
; Build: build.cmd (needs Inno Setup 6, ISCC.exe).

#define AppVersion "1.0.0"
#define AppGuid "2E023C08-71B2-4D88-B055-1FFD43B4BB7E"
#define NeedFFmpeg

[Setup]
AppId={{{#AppGuid}}
AppName=mono-izer
AppVersion={#AppVersion}
AppPublisher=DVLCE
AppPublisherURL=https://webdev.dvlce.ca/mono-izer
AppSupportURL=https://github.com/toyuvalo/mono-izer
VersionInfoVersion={#AppVersion}
VersionInfoDescription=mono-izer Setup
PrivilegesRequired=lowest
DefaultDirName={localappdata}\MonoIzer
DisableDirPage=yes
DisableProgramGroupPage=yes
OutputDir=..
OutputBaseFilename=MonoIzer-Install
SetupIconFile=..\mono-izer.ico
UninstallDisplayIcon={app}\MonoIzer.exe
UninstallDisplayName=mono-izer
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes
ChangesEnvironment=yes
#ifdef SIGN
; build.cmd passes /DSIGN and /Sazsign=<command> (Azure Artifact Signing).
SignTool=azsign
SignedUninstaller=yes
#endif

[Files]
Source: "..\build\MonoIzer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\mono-izer.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\mono-izer.ico"; DestDir: "{app}"; Flags: ignoreversion

[UninstallDelete]
Type: files; Name: "{app}\mono-izer.log"

#define MenuKey(Ext) "Software\Classes\SystemFileAssociations\" + Ext + "\shell\MonoIzer"
#define Entry(Ext) \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '"; ValueType: none; Flags: deletekey' + NewLine + \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '"; ValueType: string; ValueName: ""; ValueData: "mono-izer"; Flags: uninsdeletekey' + NewLine + \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\mono-izer.ico,0"' + NewLine + \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"' + NewLine + \
  'Root: HKCU; Subkey: "' + MenuKey(Ext) + '\command"; ValueType: string; ValueName: ""; ValueData: """{app}\MonoIzer.exe"" ""%1"""' + NewLine

[Registry]
#emit Entry(".wav")
#emit Entry(".mp3")

#include "dvlce-deps.iss"

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then InstallDeps();
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then UninstallDeps();
end;
