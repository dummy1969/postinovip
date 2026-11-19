#!/usr/bin/env bash
# Pacchetto di rilascio per macOS: core .NET self-contained dentro PostinoVip.app (l'utente non installa .NET),
# firma locale («ad hoc», nessun certificato Apple) e immagine disco .dmg da trascinare in Applicazioni.
#
# Uso (sul Mac): packaging/macos/build-dmg.sh
# Risultato: dist/macos/PostinoVip.app e dist/macos/PostinoVip-<versione>-arm64.dmg
#   PostinoVip.app/Contents/MacOS/PostinoVip              app Flutter (release)
#   PostinoVip.app/Contents/MacOS/core/PostinoVip.Api     core (file singolo compresso, senza trimming)
#   PostinoVip.app/Contents/MacOS/core/libe_sqlite3.dylib SQLite nativa della copia locale (fuori dal file singolo)
#   PostinoVip.app/Contents/Resources/core/appsettings.json configurazione senza credenziali (link in MacOS/core)
#   PostinoVip.app/Contents/Resources/LICENSE, THIRD-PARTY-NOTICES-dotnet.txt
# Solo Apple Silicon (osx-arm64): il core in file singolo non si unisce con lipo in un eseguibile universale.
set -euo pipefail
trap 'echo "ERRORE alla riga $LINENO (comando: $BASH_COMMAND)" >&2' ERR

[ "$(uname -s)" = Darwin ] || { echo "Va eseguito su macOS." >&2; exit 1; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/dist/macos"
APP="$OUT/PostinoVip.app"
CORE_TMP="$OUT/.core-publish"
STAGE="$OUT/.dmg-stage"
VERSION="$(sed -n 's/^version: *\([0-9.]*\)+.*/\1/p' "$ROOT/app/pubspec.yaml")"
DMG="$OUT/PostinoVip-$VERSION-arm64.dmg"

# .NET installato con dotnet-install.sh in ~/.dotnet (come sul Mac di sviluppo) se non è nel PATH.
if ! command -v dotnet >/dev/null && [ -x "$HOME/.dotnet/dotnet" ]; then
  export DOTNET_ROOT="$HOME/.dotnet" PATH="$HOME/.dotnet:$PATH"
fi

echo "== 1/5 core (.NET self-contained osx-arm64, file singolo compresso, senza trimming)"
rm -rf "$CORE_TMP"
dotnet publish "$ROOT/core/src/PostinoVip.Api" \
  -c Release -r osx-arm64 --self-contained true \
  -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:DebugType=none \
  -o "$CORE_TMP"

echo "== 2/5 app (Flutter release)"
(cd "$ROOT/app" && flutter build macos --release)

echo "== 3/5 unione"
mkdir -p "$OUT"
rm -rf "$APP"
# ditto conserva link simbolici e attributi dei framework dentro l'app.
ditto "$ROOT/app/build/macos/Build/Products/Release/PostinoVip.app" "$APP"
CORE_DIR="$APP/Contents/MacOS/core"
CORE_RES="$APP/Contents/Resources/core"
mkdir -p "$CORE_DIR" "$CORE_RES"
# L'app cerca il core in <cartella dell'eseguibile>/core/ (CoreLauncher.findExecutable) e lo avvia da lì
# (cartella di lavoro = quella del core, dove trova appsettings.json).
# In Contents/MacOS la firma accetta solo codice: i file JSON stanno in Contents/Resources/core e accanto
# al core ci sono link simbolici relativi verso di loro.
cp "$CORE_TMP/PostinoVip.Api" "$CORE_TMP/libe_sqlite3.dylib" "$CORE_DIR/"
cp "$CORE_TMP/appsettings.json" "$CORE_RES/"
ln -s ../../Resources/core/appsettings.json "$CORE_DIR/appsettings.json"
chmod 755 "$CORE_DIR/PostinoVip.Api" "$CORE_DIR/libe_sqlite3.dylib"
# OAuth2: ID (e per Google il segreto) delle app di chi distribuisce PostinoVip (file escluso da git). Senza, Gmail non compare.
OAUTH="$ROOT/core/src/PostinoVip.Api/oauth-clients.json"
if [ -f "$OAUTH" ]; then
  cp "$OAUTH" "$CORE_RES/oauth-clients.json"
  ln -s ../../Resources/core/oauth-clients.json "$CORE_DIR/oauth-clients.json"
  echo "Incluso oauth-clients.json (accesso con Google/Microsoft)."
else
  echo "Nota: oauth-clients.json assente: il pacchetto non avrà Gmail né l'accesso con Microsoft."
fi
rm -rf "$CORE_TMP"
# Licenza AGPL di PostinoVip e avvisi del runtime .NET incluso nel core self-contained
# (le licenze delle librerie sono anche nell'app: Informazioni -> Visualizza licenze).
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
DOTNET_DIR="$(dirname "$(readlink -f "$(command -v dotnet)")")"
cp "$DOTNET_DIR/ThirdPartyNotices.txt" "$APP/Contents/Resources/THIRD-PARTY-NOTICES-dotnet.txt"

echo "== 4/5 firma locale (ad hoc)"
# Aggiungere file all'app invalida la firma fatta da Xcode: si firmano prima i programmi del core,
# poi l'app (che sigilla anche i file non eseguibili del core), conservando gli entitlements della build.
codesign --force --sign - "$CORE_DIR/libe_sqlite3.dylib"
codesign --force --sign - "$CORE_DIR/PostinoVip.Api"
codesign --force --sign - --preserve-metadata=entitlements,identifier,flags "$APP"
codesign --verify --deep --strict --verbose=1 "$APP"

echo "== 5/5 immagine disco"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/PostinoVip.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/LICENSE" "$STAGE/LICENSE.txt"
hdiutil create -volname "PostinoVip $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
hdiutil verify "$DMG" >/dev/null

echo "== pronto: $DMG ($(du -sh "$DMG" | cut -f1)); app: $APP ($(du -sh "$APP" | cut -f1))"
