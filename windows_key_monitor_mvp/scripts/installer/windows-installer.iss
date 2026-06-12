#ifndef AppName
  #define AppName "key-monitor"
#endif

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

#ifndef MainExeName
  #define MainExeName "windows_key_monitor_mvp.exe"
#endif

#ifndef SourceDir
  #error SourceDir must be provided. Example: /DSourceDir=C:\\path\\to\\publish
#endif

#ifndef OutputDir
  #error OutputDir must be provided. Example: /DOutputDir=C:\\path\\to\\dist
#endif

#ifndef OutputBaseFilename
  #define OutputBaseFilename "key-monitor-setup"
#endif

#ifndef Arch
  #define Arch "win-x64"
#endif

#if Arch == "win-arm64"
  #define ArchAllowed "arm64"
#else
  #define ArchAllowed "x64compatible"
#endif

[Setup]
AppId={{5D12FF59-BD7A-4A49-A2A8-2F4D61D740A4}
AppName=Key Monitor
AppVersion={#AppVersion}
AppPublisher=Key Monitor
DefaultDirName={autopf}\\Key Monitor
DefaultGroupName=Key Monitor
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed={#ArchAllowed}
ArchitecturesInstallIn64BitMode={#ArchAllowed}
WizardStyle=modern
PrivilegesRequired=admin
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\\{#MainExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\\Key Monitor"; Filename: "{app}\\{#MainExeName}"
Name: "{autodesktop}\\Key Monitor"; Filename: "{app}\\{#MainExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Run]
Filename: "{app}\\{#MainExeName}"; Description: "Launch Key Monitor"; Flags: nowait postinstall skipifsilent
