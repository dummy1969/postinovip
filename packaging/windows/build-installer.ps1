# Installer di PostinoVip per Windows (6d): core .NET self-contained + app Flutter release + runtime C++
# in dist\windows\postinovip\, poi Inno Setup -> dist\windows\PostinoVip-Setup-<versione>.exe.
#
# Uso (dalla cartella del repository, in PowerShell):
#   powershell -ExecutionPolicy Bypass -File packaging\windows\build-installer.ps1
#   (facoltativo) -InnoCompiler "C:\percorso\ISCC.exe"
# Requisiti: quelli dello sviluppo su Windows (Flutter, .NET SDK 10, Visual Studio con C++) e Inno Setup 6.
# Non firma l'installer (scelta 3a): al primo avvio Windows SmartScreen chiede conferma.
param([string]$InnoCompiler = "")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Step([string]$text) { Write-Host "== $text" -ForegroundColor Cyan }
function Run([string]$what, [scriptblock]$cmd) {
  & $cmd
  if ($LASTEXITCODE -ne 0) { throw "$what non riuscito (codice $LASTEXITCODE)" }
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
# flutter build windows rifiuta questi caratteri nel percorso (verificato il 02/11/2026).
if ($Root.IndexOfAny("#!`$^&*=|,;<>?".ToCharArray()) -ge 0) {
  throw "Il percorso '$Root' contiene caratteri che Flutter rifiuta (#!`$^&*=|,;<>?): clonare il progetto altrove."
}
$Out = Join-Path $Root "dist\windows"
$Bundle = Join-Path $Out "postinovip"
$CoreTmp = Join-Path $Out ".core-publish"
$Version = (Select-Xml -Path (Join-Path $Root "core\Directory.Build.props") -XPath "//Version").Node.InnerText
Write-Host "PostinoVip $Version"

# Inno Setup: trovato prima, così non si compila per niente se manca.
$candidates = @($InnoCompiler,
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") | Where-Object { $_ -and (Test-Path $_) }
$Iscc = $candidates | Select-Object -First 1
if (-not $Iscc) {
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { $Iscc = $cmd.Source }
}
if (-not $Iscc) { throw "Inno Setup 6 non trovato (ISCC.exe): installarlo da https://jrsoftware.org/isdl.php o passare -InnoCompiler." }
Write-Host "Inno Setup: $Iscc"

# Runtime C++ (msvcp140, vcruntime140, vcruntime140_1) da Visual Studio, accanto all'eseguibile
# ("application-local", come indica la guida di Flutter per Windows).
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw "vswhere.exe non trovato: serve Visual Studio con 'Sviluppo di applicazioni desktop con C++'." }
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw "Visual Studio con gli strumenti C++ x64 non trovato." }
$redist = Get-ChildItem (Join-Path $vs "VC\Redist\MSVC") -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^\d+(\.\d+)+$' } | Sort-Object { [version]$_.Name } -Descending |
  ForEach-Object { Get-ChildItem (Join-Path $_.FullName "x64") -Directory -Filter "Microsoft.VC*.CRT" -ErrorAction SilentlyContinue } |
  Select-Object -First 1
if (-not $redist) { throw "Cartella VC\Redist\MSVC\<versione>\x64\Microsoft.VC*.CRT non trovata in $vs." }
$CrtDlls = "msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll"
Write-Host "Runtime C++: $($redist.FullName)"

Step "1/4 core (.NET self-contained, file singolo compresso, senza trimming)"
if (Test-Path $CoreTmp) { Remove-Item $CoreTmp -Recurse -Force }
Run "dotnet publish" {
  dotnet publish (Join-Path $Root "core\src\PostinoVip.Api") -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:DebugType=none -o $CoreTmp
}

Step "2/4 app (Flutter release)"
Push-Location (Join-Path $Root "app")
try { Run "flutter build windows" { flutter build windows --release } } finally { Pop-Location }
$Release = Join-Path $Root "app\build\windows\x64\runner\Release"

Step "3/4 unione in $Bundle"
if (Test-Path $Bundle) { Remove-Item $Bundle -Recurse -Force }
Copy-Item $Release $Bundle -Recurse
foreach ($dll in $CrtDlls) { Copy-Item (Join-Path $redist.FullName $dll) $Bundle }
$CoreDir = New-Item (Join-Path $Bundle "core") -ItemType Directory
# Solo i file necessari: eseguibile, configurazione (senza credenziali) e la SQLite nativa della copia
# locale (e_sqlite3.dll: il file singolo non include le librerie native). Non serve
# aspnetcorev2_inprocess.dll (solo per IIS), né web.config.
Copy-Item (Join-Path $CoreTmp "PostinoVip.Api.exe"), (Join-Path $CoreTmp "appsettings.json"), (Join-Path $CoreTmp "e_sqlite3.dll") $CoreDir
# OAuth2 (scelta 5a): ID e segreto dell'app Google di chi distribuisce (file escluso da git).
$OAuth = Join-Path $Root "core\src\PostinoVip.Api\oauth-clients.json"
if (Test-Path $OAuth) {
  Copy-Item $OAuth $CoreDir
  Write-Host "Incluso oauth-clients.json (accesso con Google)."
} else {
  Write-Host "Nota: oauth-clients.json assente: il pacchetto non avrà Gmail." -ForegroundColor Yellow
}
Remove-Item $CoreTmp -Recurse -Force
# Licenza AGPL di PostinoVip e avvisi del runtime .NET incluso nel core self-contained.
Copy-Item (Join-Path $Root "LICENSE") $Bundle
$DotnetDir = Split-Path (Get-Command dotnet).Source
$Notices = Join-Path $DotnetDir "ThirdPartyNotices.txt"
if (Test-Path $Notices) {
  Copy-Item $Notices (Join-Path $CoreDir "THIRD-PARTY-NOTICES-dotnet.txt")
} else {
  Write-Host "Nota: $Notices non trovato: avvisi del runtime .NET non inclusi." -ForegroundColor Yellow
}

$required = @("postinovip.exe", "flutter_windows.dll", "data\icudtl.dat", "data\app.so", "LICENSE",
  "core\PostinoVip.Api.exe", "core\appsettings.json", "core\e_sqlite3.dll") + $CrtDlls
$missing = $required | Where-Object { -not (Test-Path (Join-Path $Bundle $_)) }
if ($missing) { throw "Mancano nel bundle: $($missing -join ', ')" }
$size = (Get-ChildItem $Bundle -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ("Bundle pronto: {0:N0} MB" -f $size)

Step "4/4 installer (Inno Setup)"
Run "Inno Setup" {
  & $Iscc /Q "/DAppVersion=$Version" "/DSourceDir=$Bundle" "/DOutputDir=$Out" (Join-Path $PSScriptRoot "postinovip.iss")
}
$Setup = Join-Path $Out "PostinoVip-Setup-$Version.exe"
$hash = (Get-FileHash $Setup -Algorithm SHA256).Hash.ToLower()
Write-Host ("== pronto: {0} ({1:N0} MB)" -f $Setup, ((Get-Item $Setup).Length / 1MB)) -ForegroundColor Green
Write-Host "SHA-256: $hash"
