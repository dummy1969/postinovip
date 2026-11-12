#!/usr/bin/env bash
# AppImage (un solo file eseguibile, quasi tutte le distribuzioni) a partire da dist/linux/postinovip/.
#
# Uso: packaging/linux/build-appimage.sh   (ricompila sempre il bundle con build-bundle.sh)
# Risultato: dist/linux/PostinoVip-<versione>-x86_64.AppImage
# Esecuzione: chmod +x PostinoVip-*.AppImage && ./PostinoVip-*.AppImage   (richiede FUSE)
#
# ATTENZIONE: scarica ed esegue appimagetool (progetto AppImage, GitHub). Versione fissata e
# verificata con SHA-256: se l'hash non corrisponde il file viene scartato e lo script si ferma.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUNDLE="$ROOT/dist/linux/postinovip"
APP_ID="com.dumm1969.postinovip"
VERSION="$(grep '^version:' "$ROOT/app/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
TOOLS="$ROOT/dist/tools"

# Strumenti a versione fissata, verificati con lo SHA-256 pubblicato da GitHub per le release
# (API: assets[].digest, letto il 29/10/2026). Se cambiano, aggiornare versione e hash insieme.
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
# Runtime incluso nell'AppImage: passato esplicitamente, altrimenti appimagetool lo scaricherebbe
# da solo senza verifica.
RUNTIME_URL="https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64"
RUNTIME_SHA256="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"

fetch() { # url sha256 destinazione
  if [ -f "$3" ] && echo "$2  $3" | sha256sum -c --quiet - 2>/dev/null; then
    return # già presente e integro
  fi
  echo "== download $(basename "$3")"
  curl -fsSL "$1" -o "$3.part"
  if ! echo "$2  $3.part" | sha256sum -c --quiet -; then
    rm -f "$3.part"
    echo "ERRORE: SHA-256 di $(basename "$3") non corrispondente, file scartato." >&2
    exit 1
  fi
  mv "$3.part" "$3"
}

mkdir -p "$TOOLS"
fetch "$APPIMAGETOOL_URL" "$APPIMAGETOOL_SHA256" "$TOOLS/appimagetool-1.9.1-x86_64.AppImage"
fetch "$RUNTIME_URL" "$RUNTIME_SHA256" "$TOOLS/runtime-20251108-x86_64"
chmod +x "$TOOLS/appimagetool-1.9.1-x86_64.AppImage"

# Sempre: un bundle rimasto da una build precedente finirebbe nel pacchetto senza le modifiche nuove.
"$HERE/build-bundle.sh"

APPDIR="$ROOT/dist/linux/appimage/PostinoVip.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/share/icons/hicolor/256x256/apps"
cp -a "$BUNDLE" "$APPDIR/usr/lib/postinovip"

# AppRun: punto di ingresso. L'AppImage viene montata in una cartella temporanea; l'app trova
# il core accanto al proprio eseguibile, quindi dentro l'immagine (sola lettura: va bene).
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/lib/postinovip/postinovip" "$@"
APPRUN
chmod 755 "$APPDIR/AppRun"

cp "$HERE/$APP_ID.desktop" "$APPDIR/"
cp "$HERE/$APP_ID.png" "$APPDIR/$APP_ID.png"
cp "$HERE/$APP_ID.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/"
ln -sf "$APP_ID.png" "$APPDIR/.DirIcon"
chmod -R u=rwX,go=rX "$APPDIR"

OUT="$ROOT/dist/linux/PostinoVip-${VERSION}-x86_64.AppImage"
rm -f "$OUT"
ARCH=x86_64 "$TOOLS/appimagetool-1.9.1-x86_64.AppImage" --no-appstream \
  --runtime-file "$TOOLS/runtime-20251108-x86_64" "$APPDIR" "$OUT"
echo "== pronto: $OUT ($(du -h "$OUT" | cut -f1))"
