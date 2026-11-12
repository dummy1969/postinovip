#!/usr/bin/env bash
# Build di rilascio per Linux: core .NET self-contained + app Flutter release in una cartella
# pronta (dist/linux/postinovip/), base per i pacchetti .deb e AppImage.
#
# Uso: packaging/linux/build-bundle.sh
# Risultato: dist/linux/postinovip/{postinovip, lib/, data/, LICENSE, core/PostinoVip.Api, core/appsettings.json,
#            core/libe_sqlite3.so, core/THIRD-PARTY-NOTICES-dotnet.txt}
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/dist/linux"
BUNDLE="$OUT/postinovip"
CORE_TMP="$OUT/.core-publish"

echo "== 1/3 core (.NET self-contained, file singolo compresso, senza trimming)"
rm -rf "$CORE_TMP"
dotnet publish "$ROOT/core/src/PostinoVip.Api" \
  -c Release -r linux-x64 --self-contained true \
  -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:DebugType=none \
  -o "$CORE_TMP"

echo "== 2/3 app (Flutter release)"
(cd "$ROOT/app" && flutter build linux --release)

echo "== 3/3 unione"
rm -rf "$BUNDLE"
cp -a "$ROOT/app/build/linux/x64/release/bundle" "$BUNDLE"
# xclip precompilato (GPL) incluso da quill_native_bridge_linux: non serve, gli appunti dell'editor li legge
# il programma nativo con GTK (linux/runner/clipboard_channel.cc). Tolto per non distribuire un programma
# GPL di cui non abbiamo il sorgente corrispondente; se ne resta uno, il bundle non è valido.
rm -f "$BUNDLE/data/flutter_assets/packages/quill_native_bridge_linux/assets/xclip"
if find "$BUNDLE" -name xclip | grep -q .; then
  echo "ERRORE: nel bundle c'è ancora un xclip:"; find "$BUNDLE" -name xclip; exit 1
fi
mkdir -p "$BUNDLE/core"
# Solo i file necessari: eseguibile, configurazione (senza credenziali) e la SQLite nativa della
# cache (libe_sqlite3.so: il file singolo non include le librerie native, vanno accanto all'eseguibile).
cp "$CORE_TMP/PostinoVip.Api" "$CORE_TMP/appsettings.json" "$CORE_TMP/libe_sqlite3.so" "$BUNDLE/core/"
# OAuth2: ID (e per Google il segreto) delle app di chi distribuisce PostinoVip (file escluso da git). Senza, Gmail non compare.
OAUTH="$ROOT/core/src/PostinoVip.Api/oauth-clients.json"
if [ -f "$OAUTH" ]; then
  cp "$OAUTH" "$BUNDLE/core/oauth-clients.json"
  echo "Incluso oauth-clients.json (accesso con Google/Microsoft)."
else
  echo "Nota: oauth-clients.json assente: il pacchetto non avrà Gmail né l'accesso con Microsoft."
fi
rm -rf "$CORE_TMP"
# Licenza AGPL di PostinoVip e avvisi del runtime .NET incluso nel core self-contained
# (le licenze delle librerie sono anche nell'app: Informazioni -> Visualizza licenze).
cp "$ROOT/LICENSE" "$BUNDLE/LICENSE"
DOTNET_ROOT_DIR="$(dirname "$(readlink -f "$(command -v dotnet)")")"
cp "$DOTNET_ROOT_DIR/ThirdPartyNotices.txt" "$BUNDLE/core/THIRD-PARTY-NOTICES-dotnet.txt"

echo "== pronto: $BUNDLE ($(du -sh "$BUNDLE" | cut -f1))"
