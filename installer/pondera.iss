#define AppName "Pondera"
#define AppVersion "1.0.8"
#define AppPublisher "Bitgenial"
#define AppExecutable "pondera.exe"
#define BuildDirectory "..\build\windows\x64\runner\Release"

[Setup]
AppId={{1B54DC0E-8B4A-4AC7-9E2A-1091C6D8A047}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=Pondera-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExecutable}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes
RestartApplications=no
VersionInfoVersion=1.0.8.9
VersionInfoCompany={#AppPublisher}
VersionInfoDescription=Instalador de {#AppName}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos adicionales:"; Flags: unchecked

[Files]
Source: "{#BuildDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExecutable}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExecutable}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExecutable}"; Description: "Abrir {#AppName}"; Flags: nowait postinstall skipifsilent
