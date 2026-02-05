; Mec-Dis Soporte Remoto — Setup (Inno Setup)
; NOTE: This is optional. If you already use rustdesk-portable-packer output as "installer",
; you may ignore this. If you want a classic wizard installer, use this .iss.

#define MyAppName "Mec-Dis Soporte Remoto"
#define MyAppPublisher "Mec-Dis Computadoras"
#define MyAppURL "https://mec-dis.com" ; cambia si quieres
#define MyAppExeName "mecdis-soporte-remoto.exe"

; Build output folder from Flutter Windows release:
#define BuildDir "flutter\\build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{D2D1B7F0-0A7C-4D37-9A5E-2F1A5E5D0DAB}
AppName={#MyAppName}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Mec-Dis\Soporte Remoto
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=Mec-Dis-Soporte-Remoto-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; Icon
SetupIconFile=flutter\\windows\\runner\\resources\\app_icon.ico
UninstallDisplayIcon={app}\\{#MyAppExeName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el Escritorio"; GroupDescription: "Accesos directos:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"
Name: "{commondesktop}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\\{#MyAppExeName}"; Description: "Abrir {#MyAppName}"; Flags: nowait postinstall skipifsilent
