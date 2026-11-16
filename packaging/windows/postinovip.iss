; Installer di PostinoVip per Windows (Inno Setup 6). Non va compilato a mano: lo lancia
; packaging\windows\build-installer.ps1, che prepara la cartella del programma e passa:
;   /DAppVersion=0.0.N  /DSourceDir=<cartella del programma>  /DOutputDir=<dove scrivere il Setup>
; Scelte dell'utente (6d, 05/11/2026): Inno Setup (1a), solo per l'utente corrente senza
; amministratore (2a), senza firma (3a).

#ifndef AppVersion
  #error Manca /DAppVersion: usare build-installer.ps1
#endif
#ifndef SourceDir
  #error Manca /DSourceDir: usare build-installer.ps1
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

#define AppName "PostinoVip"
#define AppExe "postinovip.exe"
; Stesso identificativo delle notifiche (app/lib/notify/system_notifier.dart).
#define AppUserModelId "Dumm1969.PostinoVip"

[Setup]
ShowLanguageDialog=auto
; AppId fisso: identifica il programma per aggiornamenti e disinstallazione. Non cambiarlo mai.
AppId={{87660B32-165E-4DFB-AB99-7E8DE910162D}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Marcello Anderlini
AppCopyright=© 2026 Marcello Anderlini, AGPL-3.0-or-later
VersionInfoVersion={#AppVersion}
; Solo per l'utente corrente: con "lowest" {autopf} = %LOCALAPPDATA%\Programs, niente richiesta di amministratore.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Windows 10 o più recente (requisito di Flutter desktop).
MinVersion=10.0
LicenseFile={#SourceDir}\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename=PostinoVip-Setup-{#AppVersion}
SetupIconFile=..\..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Se PostinoVip è aperto, chiede di chiuderlo (il core si chiude insieme all'app).
CloseApplications=yes
RestartApplications=no

; Lingua dell'installazione come quella di Windows (tappa «Lingua», L7): italiano o inglese; le altre lingue -> inglese,
; come l'app. La finestra di scelta compare solo se la lingua di Windows non è tra queste.
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Aggiornamento: tolti i file della versione precedente che potrebbero non esserci più.
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\core"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "{#AppUserModelId}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "{#AppUserModelId}"; Tasks: desktopicon

[Registry]
; Chiavi scritte dal plugin delle notifiche al primo avvio: tolte con la disinstallazione (non le crea l'installer).
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\{#AppUserModelId}"; Flags: uninsdeletekey dontcreatekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\PushNotifications\Backup\{#AppUserModelId}"; Flags: uninsdeletekey dontcreatekey

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; La disinstallazione toglie solo il programma: copia locale della posta (%LOCALAPPDATA%\postinovip,
; per gli account POP3 l'unica copia delle mail), impostazioni e account nel portachiavi restano.
