#!/usr/bin/env bash
# Verifica 3.6a (core): conversazioni, account "main" (user-secrets). SOLA LETTURA: nessuna modifica alla
# casella (References si legge con BODY.PEEK[HEADER.FIELDS (REFERENCES)], come le altre intestazioni).
# Avvia il core di sviluppo con il download in background, aspetta che il passaggio riempia References
# per le mail già in cache (migrazione allo schema 7), poi controlla database ed endpoint /conversations.
# Chiudere prima l'app (stessa copia locale di sviluppo, ~/.local/share/postinovip-dev).
# Gli oggetti delle mail compaiono solo in questo terminale.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
DB=$HOME/.local/share/postinovip-dev/accounts/main/index.db
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-conversazioni-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero. Niente IDLE; download sì.
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Api__Port=5096 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5096/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5096
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}
sql() { python3 -I -c 'import sqlite3,sys; print(sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True).execute(sys.argv[2]).fetchone()[0])' "$DB" "$1"; }

ADDRESS=$(curl -s -H "$H" "$U/accounts" | python3 -I -c 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
echo "Account: $ADDRESS (sola lettura)"

echo "1. Passaggio in background (References per le mail già in cache), al massimo 5 minuti"
for i in $(seq 300); do
  [ "$(sql 'PRAGMA user_version' 2>/dev/null)" = 7 ] && [ "$(sql 'SELECT count(*) FROM messages WHERE refs IS NULL' 2>/dev/null)" = 0 ] && break
  sleep 1
done
sleep 2 # fine del passaggio: ricalcolo delle conversazioni
grep -E "References aggiunte|conversazioni ricalcolate|passaggio completato" "$WORK/core.log" | sed 's/^/         /' | head -20
check "schema del database" "$(sql 'PRAGMA user_version')" 7
check "mail con References non ancora nota" "$(sql 'SELECT count(*) FROM messages WHERE refs IS NULL')" 0
echo "         mail: $(sql 'SELECT count(*) FROM messages'), con References: $(sql "SELECT count(*) FROM messages WHERE refs <> ''"), con In-Reply-To: $(sql 'SELECT count(*) FROM messages WHERE in_reply_to IS NOT NULL')"
echo "         conversazioni con più mail nell'account: $(sql 'SELECT count(*) FROM (SELECT thread_id FROM messages GROUP BY thread_id HAVING count(*) > 1)')"

echo "2. Endpoint /folders/{cartella}/conversations"
for F in INBOX "Posta inviata"; do
  ENC=$(python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$F")
  START=$(date +%s.%N)
  CODE=$(curl -s -o "$WORK/page.json" -w "%{http_code}" -H "$H" "$U/folders/$ENC/conversations?limit=200")
  END=$(date +%s.%N)
  check "$F: codice" "$CODE" 200
  python3 -I - "$WORK/page.json" "$F" "$START" "$END" <<'EOF'
import json, sys
page = json.load(open(sys.argv[1])); folder = sys.argv[2]
items = page["items"]
here = sum(1 for c in items for m in c["messages"] if m["folder"] == folder)
multi = [c for c in items if c["count"] > 1]
print(f"         {page['total']} conversazioni ({len(items)} nella prima pagina, {here} mail di {folder}), "
      f"{len(multi)} con più mail, {float(sys.argv[4]) - float(sys.argv[3]):.2f} s")
for c in multi[:5]:
    latest = c["messages"][0]["message"]
    where = ", ".join(sorted({m["folder"] for m in c["messages"]}))
    print(f"           - {c['count']} mail ({where}): {latest['subject'][:70]}")
ok = all(c["count"] == len(c["messages"]) and any(m["folder"] == folder for m in c["messages"]) for c in items)
print("         coerenza (numero = mail, almeno una della cartella):", "sì" if ok else "NO")
EOF
done
R=$(curl -s -o /dev/null -w "%{http_code}" -H "$H" "$U/folders/INBOX/conversations?limit=0"); check "limit=0" "$R" 400

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
