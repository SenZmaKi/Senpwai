#ifndef AppVersion
  #define AppVersion "3.0.0"
#endif
#ifndef AppArchitecture
  #define AppArchitecture "x64"
#endif
#ifndef SourceDir
  #define SourceDir AddBackslash(SourcePath) + "..\\build\\windows\\" + AppArchitecture + "\\runner\\Release"
#endif
#ifndef OutputDir
  #define OutputDir AddBackslash(SourcePath) + "..\\build\\release\\windows"
#endif

#define AppName "Senpwai"
#define AppPublisher "Senpwai"
#define AppUrl "https://github.com/SenZmaKi/Senpwai"
#define AppExeName "senpwai.exe"
#define AppDataDir "{userappdata}\\com.senpwai.app\\Senpwai\\SenpwaiData"

#if AppArchitecture == "arm64"
  #define AllowedArchitectures "arm64"
#elif AppArchitecture == "x64"
  #define AllowedArchitectures "x64compatible and not arm64"
#else
  #error Unsupported AppArchitecture. Expected x64 or arm64.
#endif

[Setup]
AppId={{902B5BE6-4A98-45C1-ACC8-100676202200}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
ArchitecturesAllowed={#AllowedArchitectures}
ArchitecturesInstallIn64BitMode={#AllowedArchitectures}
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=Senpwai-windows-{#AppArchitecture}-setup
SetupIconFile={#SourcePath}\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  RemoveAppData: Boolean;

function HasCommandLineParameter(const Name: String): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 1 to ParamCount do
  begin
    if CompareText(ParamStr(Index), Name) = 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if (CurStep = ssPostInstall) and HasCommandLineParameter('/LAUNCH') then
  begin
    if not Exec(
      ExpandConstant('{app}\{#AppExeName}'),
      '',
      '',
      SW_SHOWNORMAL,
      ewNoWait,
      ResultCode
    ) then
      Log(Format('Could not relaunch Senpwai. Error code: %d', [ResultCode]));
  end;
end;

function InitializeUninstall(): Boolean;
begin
  if HasCommandLineParameter('/REMOVEAPPDATA') then
    RemoveAppData := True
  else if UninstallSilent or HasCommandLineParameter('/KEEPAPPDATA') then
    RemoveAppData := False
  else
    RemoveAppData :=
      MsgBox(
        'Also remove Senpwai settings, tracked anime, login sessions, cache, and logs?' + #13#10 + #13#10 +
        'Downloaded anime will not be removed.',
        mbConfirmation,
        MB_YESNO or MB_DEFBUTTON2
      ) = IDYES;
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usPostUninstall) and RemoveAppData then
  begin
    if not DelTree(ExpandConstant('{#AppDataDir}'), True, True, True) then
      MsgBox(
        'Some Senpwai application data could not be removed.',
        mbError,
        MB_OK
      );
  end;
end;
