#!/usr/bin/env bash
# Verifica R1 (core): conferma di lettura, account "main" (user-secrets).
# INVIA DAVVERO MAIL e MODIFICA LA CASELLA, solo con l'indirizzo dell'account stesso:
#   1. invia a te stesso due mail di prova che chiedono la conferma di lettura (senza copia in Posta inviata);
#   2. all'arrivo: la prima riceve la risposta «Invia» (parte una conferma «Letto: …», di nuovo a te),
#      la seconda «Non inviare» (nessuna mail); tutte e due diventano $MDNSent sul server;
#   3. controlla che la conferma arrivi, che non chieda a sua volta una conferma e che una seconda risposta sia
#      rifiutata (409);
#   4. sposta in Posta eliminata le tre mail di prova (le due di prova e la conferma). Nessun'altra mail toccata.
# Chiede conferma prima di cominciare. Chiudere prima l'app (stessa copia locale di sviluppo).
# Mostra solo numeri, sì/no e gli oggetti delle mail di prova.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
DB=$HOME/.local/share/postinovip-dev/accounts/main/index.db
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-conferma-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero. Niente IDLE né download in background.
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Cache__Download__Enabled=false Api__Port=5112 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5112/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5112
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}
py() { python3 -I -c "$1" "${@:2}"; }
post() { curl -s -o "$WORK/r.json" -w "%{http_code}" -X POST -H "$H" -H "Content-Type: application/json" --data "$2" "$U$1"; }
field() { py 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2]); print("null" if v is None else v)' "$WORK/r.json" "$1"; }
# UID della mail con l'oggetto $1 in INBOX (la lista sincronizza prima con il server); vuoto se non c'è.
uid_of() { curl -s -H "$H" "$U/folders/INBOX/messages?limit=50" | py 'import json,sys; print(next((m["uid"] for m in json.load(sys.stdin)["items"] if m["subject"]==sys.argv[1]), ""))' "$1"; }
wait_for() { # aspetta fino a 3 minuti che arrivi la mail con oggetto $1
  local u=""
  for i in $(seq 36); do u=$(uid_of "$1"); [ -n "$u" ] && break; sleep 5; done
  echo "$u"
}
detail() { curl -s -H "$H" "$U/messages/INBOX/$1" | py 'import json,sys; d=json.load(sys.stdin); print(d.get(sys.argv[1]))' "$2"; }
flags() { python3 -I -c 'import sqlite3,sys; r=sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True).execute("SELECT m.flags FROM messages m JOIN folders f ON f.id = m.folder_id WHERE f.full_name = ? AND m.uid = ?", ("INBOX", int(sys.argv[2]))).fetchone(); print(r[0] if r else -1)' "$DB" "$1"; }

ADDRESS=$(curl -s -H "$H" "$U/accounts" | py 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
TAG=$(date '+%d/%m/%Y %H:%M:%S')
S1="PostinoVip prova conferma A $TAG"
S2="PostinoVip prova conferma B $TAG"

echo "Account: $ADDRESS"
echo "La prova INVIA a $ADDRESS (solo a te) due mail che chiedono la conferma di lettura:"
echo "  «$S1» (risposta: Invia -> parte una conferma «Letto: …» a te)"
echo "  «$S2» (risposta: Non inviare)"
echo "segna le due mail \$MDNSent sul server e alla fine sposta le tre mail di prova in Posta eliminata."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Invio delle due mail con la richiesta"
for S in "$S1" "$S2"; do
  BODY=$(py 'import json,sys; print(json.dumps({"to": [sys.argv[1]], "subject": sys.argv[2], "body": "Prova della conferma di lettura.", "readReceipt": True}))' "$ADDRESS" "$S")
  check "invio «${S:26:1}»" "$(post /send "$BODY")" 200
done

echo "2. Arrivo (al massimo 3 minuti)"
UID1=$(wait_for "$S1"); UID2=$(wait_for "$S2")
check "arrivata A" "$([ -n "$UID1" ] && echo sì || echo no)" sì
check "arrivata B" "$([ -n "$UID2" ] && echo sì || echo no)" sì
[ -n "$UID1" ] && [ -n "$UID2" ] || { echo "Mail non arrivate: interrompo."; exit 1; }
check "A chiede la conferma al mittente (receiptTo)" "$(detail "$UID1" receiptTo)" "$ADDRESS"
check "A non ancora trattata (receiptHandled)" "$(detail "$UID1" receiptHandled)" False

echo "3. Risposte"
check "A: Invia" "$(post "/messages/INBOX/$UID1/receipt" '{"send": true}')" 200
check "A: risposta sent" "$(field sent)" True
check "B: Non inviare" "$(post "/messages/INBOX/$UID2/receipt" '{"send": false}')" 200
check "B: risposta sent" "$(field sent)" False
check "A ora trattata (receiptHandled)" "$(detail "$UID1" receiptHandled)" True
check "A: seconda risposta rifiutata" "$(post "/messages/INBOX/$UID1/receipt" '{"send": true}')" 409
uid_of "$S1" > /dev/null # nuova sincronizzazione: i flag vengono riletti dal server
# A: il server di prova, quando riceve la conferma nella stessa casella, sostituisce $MDNSent con $MDNReceived
# (8192); per il core vale come «già trattata» (dipende dai tempi: la conferma può essere già arrivata).
check "\$MDNSent o \$MDNReceived sul server (A)" "$([ $(( $(flags "$UID1") & 12288 )) -ne 0 ] && echo sì || echo no)" sì
check "\$MDNSent rimasto sul server (B)" "$(( $(flags "$UID2") & 4096 ))" 4096

echo "4. Arrivo della conferma «Letto: …» (al massimo 3 minuti)"
UID3=$(wait_for "Letto: $S1")
check "conferma arrivata" "$([ -n "$UID3" ] && echo sì || echo no)" sì
if [ -n "$UID3" ]; then
  check "la conferma non chiede a sua volta una conferma" "$(detail "$UID3" receiptTo)" None
  check "nessuna conferma per B («Non inviare»)" "$(uid_of "Letto: $S2")" ""
  check "A ancora «già trattata» dopo l'arrivo della conferma" "$(detail "$UID1" receiptHandled)" True
fi

echo "5. Pulizia: le mail di prova in Posta eliminata"
UIDS=$(py 'import sys; print(",".join(u for u in sys.argv[1:] if u))' "$UID1" "$UID2" "${UID3:-}")
check "spostate" "$(post /messages/INBOX/delete "{\"uids\": [$UIDS], \"permanent\": false}")" 200

echo
echo "Righe del core sulle conferme:"
grep -E "conferma di lettura|MDNSent" "$WORK/core.log" | sed 's/^/         /'
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
