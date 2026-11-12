#!/usr/bin/env bash
# Verifica 8e-2 (core): dati locali degli account rimossi e "Ricostruisci cache", su una cartella di
# cache TEMPORANEA (copia del database di "main" + un finto account rimosso), cancellata alla fine.
# La cache vera in ~/.local/share/postinovip-dev non viene toccata; il server è finto (porta chiusa).
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
SRC=$HOME/.local/share/postinovip-dev/accounts/main/index.db
[ -f "$SRC" ] || { echo "Cache di sviluppo non trovata: $SRC"; exit 1; }
[ -x "$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-dati-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

# Cache di prova: "main" (copia coerente) e "vecchio1", un account non più configurato con 3 MB di dati.
mkdir -p "$WORK/accounts/main" "$WORK/accounts/vecchio1/bodies"
python3 -I -c "import sqlite3,sys; s=sqlite3.connect(f'file:{sys.argv[1]}?mode=ro',uri=True); d=sqlite3.connect(sys.argv[2]); s.backup(d); d.close()" "$SRC" "$WORK/accounts/main/index.db"
head -c 3000000 /dev/zero > "$WORK/accounts/vecchio1/bodies/x.eml"
echo '{"Id":"vecchio1","Name":"Vecchio","Address":"vecchio@example.com"}' > "$WORK/accounts/vecchio1/account.json"

PORT=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero.
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Cache__Download__Enabled=false Cache__Directory="$WORK" Api__Port=5097 Imap__Host=127.0.0.1 Imap__Port=$PORT \
  Smtp__Host=127.0.0.1 Smtp__Port=$PORT ./bin/Debug/net10.0/PostinoVip.Api > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5097/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5097
code() { curl -s -o /dev/null -w "%{http_code}" -X "$1" -H "$H" "$U$2"; }

echo "1. Cartelle di main (dalla copia):            $(code GET /folders)   (atteso 200)"
echo "2. Dati di account rimossi:"
curl -s -H "$H" "$U/cache/orphans" | python3 -I -c '
import json, sys
for o in json.load(sys.stdin):
    print("     %s: %s, %.1f MB" % (o["id"], o["address"], o["sizeBytes"] / 1048576))'
echo "3. Elimina i dati di main (configurato):      $(code DELETE /cache/orphans/main)   (atteso 409: non è rimosso)"
echo "4. Elimina i dati di vecchio1:                $(code DELETE /cache/orphans/vecchio1)   (atteso 204)"
echo "   cartelle rimaste: $(ls "$WORK/accounts" | tr '\n' ' ')  (atteso: solo main)"
echo "5. Ricostruisci la cache di main:             $(code POST /accounts/main/cache/rebuild)   (atteso 202)"
echo "   file di main: $(ls "$WORK/accounts/main" | tr '\n' ' ')"
echo "6. Cartelle di main dopo la ricostruzione:    $(code GET /folders)   (atteso 503: cache vuota e server spento)"
echo "   riga del core: $(grep -A1 PostinoVip.Cache "$WORK/core.log" | grep -o 'cache ricostruita su richiesta[^"]*' | head -1)"
