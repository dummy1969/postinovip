#!/usr/bin/env bash
# Pacchetto .deb (Debian, Ubuntu, Zorin, Mint...) a partire da dist/linux/postinovip/.
#
# Uso: packaging/linux/build-deb.sh        (ricompila sempre il bundle con build-bundle.sh)
# Risultato: dist/linux/postinovip_<versione>_amd64.deb
# Installazione: sudo apt install ./dist/linux/postinovip_<versione>_amd64.deb
# Rimozione:     sudo apt remove postinovip   (account e impostazioni dell'utente restano nel suo profilo)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUNDLE="$ROOT/dist/linux/postinovip"
APP_ID="com.dumm1969.postinovip"
VERSION="$(grep '^version:' "$ROOT/app/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"

# Sempre: un bundle rimasto da una build precedente finirebbe nel pacchetto senza le modifiche nuove.
"$HERE/build-bundle.sh"

PKG="$ROOT/dist/linux/deb/postinovip_${VERSION}_amd64"
rm -rf "$PKG"
mkdir -p "$PKG/DEBIAN" "$PKG/opt" "$PKG/usr/bin" "$PKG/usr/share/applications" "$PKG/usr/share/doc/postinovip" \
         "$PKG/usr/share/icons/hicolor/scalable/apps" "$PKG/usr/share/icons/hicolor/256x256/apps"

# Programma in /opt (cartella autonoma: app Flutter + core accanto), comando in /usr/bin.
cp -a "$BUNDLE" "$PKG/opt/postinovip"
ln -s ../../opt/postinovip/postinovip "$PKG/usr/bin/postinovip"
cp "$HERE/$APP_ID.desktop" "$PKG/usr/share/applications/"
cp "$HERE/$APP_ID.svg" "$PKG/usr/share/icons/hicolor/scalable/apps/"
cp "$HERE/$APP_ID.png" "$PKG/usr/share/icons/hicolor/256x256/apps/"

# Copyright e licenza nel posto standard dei pacchetti Debian (formato machine-readable 1.0).
cat > "$PKG/usr/share/doc/postinovip/copyright" <<COPYRIGHT
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: PostinoVip

Files: *
Copyright: 2026 Marcello Anderlini
License: AGPL-3.0-or-later
 Il testo completo della licenza è in /opt/postinovip/LICENSE.
 Licenze delle librerie incluse: nell'app, Informazioni -> Visualizza licenze;
 runtime .NET: /opt/postinovip/core/THIRD-PARTY-NOTICES-dotnet.txt.

Files: opt/postinovip/data/flutter_assets/assets/fonts/inter/*
Copyright: 2016 The Inter Project Authors
License: OFL-1.1
 Carattere Inter 4.1 (https://github.com/rsms/inter), non modificato. Testo completo della licenza:
 /opt/postinovip/data/flutter_assets/assets/licenses/inter.txt.
COPYRIGHT

# Dipendenze: GTK 3 (finestra), libsecret (portachiavi), epoxy (OpenGL di Flutter), OpenSSL
# (TLS del core: .NET la carica a runtime, ldd non la mostra). Nomi "t64" (Ubuntu 24.04) con
# l'alternativa classica (Debian 12, Ubuntu 22.04).
cat > "$PKG/DEBIAN/control" <<CONTROL
Package: postinovip
Version: $VERSION
Section: mail
Priority: optional
Architecture: amd64
Maintainer: Marcello Anderlini <dummy1969@users.noreply.github.com>
Installed-Size: $(du -sk "$PKG" | cut -f1)
Depends: libgtk-3-0t64 | libgtk-3-0, libsecret-1-0, libepoxy0, libssl3t64 | libssl3, libstdc++6, libc6
Description: Desktop mail client inspired by Outlook
 PostinoVip reads and sends mail from several IMAP/POP3/SMTP mailboxes, with
 calendar and contacts; user interface in Italian and English. It includes a
 self-contained .NET core (no .NET installation needed). Passwords are kept in
 the system keyring. License AGPL-3.0-or-later.
CONTROL

# Permessi standard (644 file, 755 cartelle ed eseguibili): non dipendono dalla umask di chi costruisce.
chmod -R u=rwX,go=rX "$PKG"

OUT="$ROOT/dist/linux/postinovip_${VERSION}_amd64.deb"
# --root-owner-group: file di proprietà di root nel pacchetto, senza bisogno di sudo per costruirlo.
dpkg-deb --root-owner-group -Zxz --build "$PKG" "$OUT"
echo "== pronto: $OUT ($(du -h "$OUT" | cut -f1))"
