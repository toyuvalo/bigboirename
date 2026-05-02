; BigBoiRename installer — registers HKCU shell-menu for files, folders, and folder backgrounds.
; Build with: ISCC.exe /DMyAppVersion=1.0.0 installer\renamemenu.iss
; Requires dist\BigBoiRename.exe already built by PyInstaller.
; Prerequisites: Ollama must be installed separately (https://ollama.com) — the installer detects and warns if missing.

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#define MyAppName "BigBoiRename"
#define MyAppPublisher "dvlce.ca"
#define MyAppURL "https://github.com/toyuvalo/bigboirename"
#define MyAppExeName "BigBoiRename.exe"
#define MyMenuLabel "BigBoi Rename"

[Setup]
AppId={{3D8B4F12-9AE5-4C23-B81D-6E2F91C5A7E8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=BigBoiRename-Setup
OutputDir=.
SetupIconFile=..\icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\icon.ico"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon

[Registry]
; All-files right-click
Root: HKCU; Subkey: "Software\Classes\*\shell\{#MyAppName}"; ValueType: string; ValueName: ""; ValueData: "{#MyMenuLabel}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\*\shell\{#MyAppName}"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\icon.ico"
Root: HKCU; Subkey: "Software\Classes\*\shell\{#MyAppName}\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

; Folder right-click
Root: HKCU; Subkey: "Software\Classes\Directory\shell\{#MyAppName}"; ValueType: string; ValueName: ""; ValueData: "{#MyMenuLabel}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\shell\{#MyAppName}"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\icon.ico"
Root: HKCU; Subkey: "Software\Classes\Directory\shell\{#MyAppName}\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

; Folder-background right-click
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\{#MyAppName}"; ValueType: string; ValueName: ""; ValueData: "{#MyMenuLabel}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\{#MyAppName}"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\icon.ico"
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\{#MyAppName}\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%V"""

[Code]
function InitializeSetup(): Boolean;
var
  OllamaFound: Boolean;
  ResultCode: Integer;
  UserPath: String;
begin
  Result := True;
  OllamaFound := False;

  if Exec('cmd.exe', '/c where ollama >nul 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    if ResultCode = 0 then OllamaFound := True;

  UserPath := ExpandConstant('{localappdata}\Programs\Ollama\ollama.exe');
  if FileExists(UserPath) then OllamaFound := True;

  UserPath := ExpandConstant('{localappdata}\Ollama\ollama.exe');
  if FileExists(UserPath) then OllamaFound := True;

  if not OllamaFound then begin
    if MsgBox('Ollama was not detected on this system.' + #13#10 + #13#10 +
             'BigBoiRename requires Ollama to run local AI. You can continue installation now, ' +
             'but you must install Ollama from https://ollama.com and then run ' +
             '"ollama pull llama3.2:1b" before BigBoiRename will work.' + #13#10 + #13#10 +
             'Continue installation?', mbConfirmation, MB_YESNO) = IDNO then
      Result := False;
  end;
end;
