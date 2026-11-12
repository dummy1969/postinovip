#!/usr/bin/env bash
# Verifica E1 (core): «Salva con nome» .eml e file .eml aperti, account "main" (user-secrets).
# SOLA LETTURA: nessuna modifica alla casella (i byte originali si leggono dalla copia locale o con BODY.PEEK[],
# i file .eml aperti restano in memoria nel core). Nessun invio.
# Prende la mail più recente di INBOX con allegati (altrimenti la più recente), la «salva» con GET …/raw,
# la riapre con POST /eml e confronta oggetto, allegati e bozza di risposta con quelli della mail nella casella.
# Chiudere prima l'app (stessa copia locale di sviluppo, ~/.local/share/postinovip-dev).
# Mostra solo numeri e sì/no: né oggetti né contenuti delle mail.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
DB=$HOME/.local/share/postinovip-dev/accounts/main/index.db
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-eml-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero. Niente IDLE né download in background.
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Cache__Download__Enabled=false Api__Port=5111 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5111/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5111
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}
json() { python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$@"; }

ADDRESS=$(curl -s -H "$H" "$U/accounts" | python3 -I -c 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
echo "Account: $ADDRESS (sola lettura, nessun invio)"

echo "1. Mail di prova: la più recente di INBOX con allegati (altrimenti la più recente)"
curl -s -H "$H" "$U/folders/INBOX/messages?limit=50" > "$WORK/list.json"
UID_=$(json "$WORK/list.json" 'next((m["uid"] for m in d["items"] if m.get("hasAttachments")), d["items"][0]["uid"] if d["items"] else "")')
[ -n "$UID_" ] || { echo "INBOX vuota: niente da provare."; exit 1; }
SEEN_BEFORE=$(json "$WORK/list.json" "next(m['seen'] for m in d['items'] if m['uid'] == $UID_)")
echo "         uid $UID_, letta: $SEEN_BEFORE"
curl -s -H "$H" "$U/messages/INBOX/$UID_" > "$WORK/detail.json"
ATT=$(json "$WORK/detail.json" 'len(d["attachments"])')
echo "         allegati: $ATT"

echo "2. «Salva con nome»: GET /messages/INBOX/$UID_/raw"
CODE=$(curl -s -o "$WORK/mail.eml" -w "%{http_code}|%{content_type}" -H "$H" "$U/messages/INBOX/$UID_/raw")
check "codice e tipo" "$CODE" "200|message/rfc822"
echo "         $(stat -c %s "$WORK/mail.eml") byte"
SHA=$(sha256sum "$WORK/mail.eml" | cut -d' ' -f1)
STORED=$(python3 -I -c 'import sqlite3,sys; r=sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True).execute("SELECT body_sha256 FROM messages m JOIN folders f ON f.id = m.folder_id WHERE f.full_name = ? AND m.uid = ?", ("INBOX", int(sys.argv[2]))).fetchone(); print(r[0] if r and r[0] else "")' "$DB" "$UID_" 2>/dev/null)
if [ -n "$STORED" ]; then check "byte uguali al file della copia locale (SHA-256)" "$([ "$SHA" = "$STORED" ] && echo sì || echo no)" sì
else echo "         corpo non nella copia locale: letto dal server con BODY.PEEK[]"; fi
check "il file è una mail con lo stesso oggetto" "$(python3 -I - "$WORK/mail.eml" "$WORK/detail.json" <<'EOF'
import email, email.policy, json, sys
m = email.message_from_bytes(open(sys.argv[1], "rb").read(), policy=email.policy.default)
print("sì" if (m["subject"] or "") == json.load(open(sys.argv[2]))["subject"] else "no")
EOF
)" sì

echo "3. Apertura del file: POST /eml"
CODE=$(curl -s -o "$WORK/open.json" -w "%{http_code}" -H "$H" -H "Content-Type: message/rfc822" --data-binary "@$WORK/mail.eml" "$U/eml")
check "codice" "$CODE" 200
ID=$(json "$WORK/open.json" 'd["id"]')
check "oggetto uguale alla mail nella casella" "$(python3 -I -c 'import json,sys; a=json.load(open(sys.argv[1]))["message"]; b=json.load(open(sys.argv[2])); print("sì" if a["subject"] == b["subject"] and a["from"] == b["from"] else "no")' "$WORK/open.json" "$WORK/detail.json")" sì
check "numero di allegati" "$(json "$WORK/open.json" 'len(d["message"]["attachments"])')" "$ATT"
SAME=sì
for i in $(seq 0 $((ATT - 1))); do
  A=$(curl -s -H "$H" "$U/eml/$ID/attachments/$i" | sha256sum | cut -d' ' -f1)
  B=$(curl -s -H "$H" "$U/messages/INBOX/$UID_/attachments/$i" | sha256sum | cut -d' ' -f1)
  [ "$A" = "$B" ] || SAME=no
done
[ "$ATT" -gt 0 ] && check "allegati uguali (SHA-256 di ognuno)" "$SAME" sì

echo "4. Bozza di risposta dal file (non invia)"
curl -s -H "$H" "$U/eml/$ID/draft?mode=replyAll" > "$WORK/draft.json"
curl -s -H "$H" "$U/messages/INBOX/$UID_/draft?mode=replyAll" > "$WORK/draft2.json"
check "uguale a quella dalla casella (oggetto, A, Cc)" "$(python3 -I -c 'import json,sys; a,b=(json.load(open(p)) for p in sys.argv[1:3]); print("sì" if (a["subject"],a["to"],a["cc"]) == (b["subject"],b["to"],b["cc"]) else "no")' "$WORK/draft.json" "$WORK/draft2.json")" sì

echo "5. File che non è una mail e chiusura"
printf 'solo testo\n' > "$WORK/testo.txt"
check "file di testo: 400" "$(curl -s -o /dev/null -w "%{http_code}" -H "$H" --data-binary "@$WORK/testo.txt" "$U/eml")" 400
check "chiusura" "$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -H "$H" "$U/eml/$ID")" 204
check "dopo la chiusura" "$(curl -s -o /dev/null -w "%{http_code}" -H "$H" "$U/eml/$ID")" 404

echo "6. La casella non è cambiata"
curl -s -H "$H" "$U/folders/INBOX/messages?limit=50" > "$WORK/list2.json"
check "stato «letta» della mail" "$(json "$WORK/list2.json" "next(m['seen'] for m in d['items'] if m['uid'] == $UID_)")" "$SEEN_BEFORE"
# Solo le righe che il core scrive quando modifica la casella o invia («[main] STORE …»): «CONDSTORE no» nella riga
# delle funzioni del server non conta (la prima versione dello script la contava).
check "comandi di modifica nel log del core" "$(grep -cE '\] (STORE|MOVE|COPY|DELETE|APPEND) |Posta in uscita: mail invi' "$WORK/core.log")" 0

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
