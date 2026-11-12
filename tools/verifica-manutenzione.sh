#!/usr/bin/env bash
# Verifica 8e-1: manutenzione della cache, su una COPIA del database dell'account "main" di sviluppo
# (l'originale in ~/.local/share/postinovip-dev non viene toccato; la copia viene cancellata alla fine).
#  1. apertura: controllo d'integrità e conversione al recupero incrementale dello spazio;
#  2. database rovinato di proposito: messo da parte come index.db.rovinato-<data> e ricreato vuoto.
# Il core usa un server finto (porta chiusa): nessun collegamento alla casella vera.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
SRC=$HOME/.local/share/postinovip-dev/accounts/main/index.db
[ -f "$SRC" ] || { echo "Cache di sviluppo non trovata: $SRC"; exit 1; }
[ -x "$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-manutenzione-XXXX)
LOG=$WORK/core.log
DB=$WORK/accounts/main/index.db
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/accounts/main"

info() {  # dimensione, pagine libere, modalità di recupero dello spazio
  python3 -I -c "
import os, sqlite3, sys
p = sys.argv[1]
db = sqlite3.connect(f'file:{p}?mode=ro', uri=True)
pc, fl, ps, av = (db.execute(f'pragma {x}').fetchone()[0] for x in ('page_count', 'freelist_count', 'page_size', 'auto_vacuum'))
print(f'  database {pc*ps/1048576:.2f} MB, spazio libero dentro {fl*ps/1048576:.2f} MB, auto_vacuum={av} ({[\"nessuno\",\"completo\",\"incrementale\"][av]})')
" "$1"
}

start_core() {
  local port
  port=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
  # exec: il PID in background è quello del core (non di una sotto-shell), così kill lo chiude davvero.
  (cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
    Cache__Download__Enabled=false Cache__Directory="$WORK" Api__Port=5096 Imap__Host=127.0.0.1 Imap__Port=$port \
    Smtp__Host=127.0.0.1 Smtp__Port=$port ./bin/Debug/net10.0/PostinoVip.Api >> "$LOG" 2>&1) &
  PID=$!
  for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5096/version && break; sleep 0.2; done
}
stop_core() { kill $PID 2>/dev/null; wait $PID 2>/dev/null; PID=; }
folders() {
  curl -s -o /dev/null -w "  GET /folders -> %{http_code} in %{time_total} s\n" \
    -H "Authorization: Bearer $POSTINOVIP_TOKEN" http://127.0.0.1:5096/folders
}

echo "1. Copia coerente del database (backup di SQLite):"
python3 -I -c "import sqlite3,sys; s=sqlite3.connect(f'file:{sys.argv[1]}?mode=ro',uri=True); d=sqlite3.connect(sys.argv[2]); s.backup(d); d.close()" "$SRC" "$DB"
info "$DB"

echo "2. Prima apertura da parte del core (controllo d'integrità + conversione):"
start_core; folders; stop_core
info "$DB"

echo "3. Database rovinato di proposito (pagine interne sovrascritte), nuova apertura:"
python3 -I -c "
import sys
with open(sys.argv[1], 'r+b') as f:
    f.seek(4096 * 3); f.write(b'\xab' * 4096 * 4)
" "$DB"
start_core; folders; stop_core
echo "  file nella cartella dell'account:"
ls -1 "$WORK/accounts/main" | sed 's/^/    /'
echo "  riga del core:"
grep -A1 "PostinoVip.Cache" "$LOG" | grep -o "cache: database rovinato.*" | sed 's/^/    /' || echo "    (nessuna)"
