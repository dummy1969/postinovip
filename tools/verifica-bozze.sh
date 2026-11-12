#!/usr/bin/env bash
# Verifica 3.8 (core): bozze sul server e Posta in uscita con invio differito, account "main" (user-secrets).
# MODIFICA LA CASELLA e INVIA DAVVERO UNA MAIL, solo all'indirizzo dell'account stesso:
#   1. salva una bozza di prova in Bozze, poi la salva di nuovo (la prima viene sostituita: ne resta una);
#   2. la riapre come farebbe l'app (testo scritto separato);
#   3. la "invia" con Ritarda recapito di 20 secondi: la bozza sparisce subito, la mail resta nella Posta in
#      uscita del computer e parte da sola (servizio in background), con la copia in Posta inviata.
# Nessun'altra mail o cartella viene toccata. La mail ricevuta e la copia restano: eliminale tu dopo.
# Chiede conferma prima di cominciare. Chiudere prima l'app (stessa copia locale di sviluppo).
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-bozze-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero. Posta in uscita attiva (predefinito).
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Cache__Download__Enabled=false Api__Port=5099 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5099/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5099
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}
py() { python3 -I -c "$1" "${@:2}"; }
post() { curl -s -o "$WORK/r.json" -w "%{http_code}" -X POST -H "$H" -H "Content-Type: application/json" --data "$2" "$U$1"; }
field() { py 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2]); print("null" if v is None else v)' "$WORK/r.json" "$1"; }
enc() { py 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
role() { curl -s -H "$H" "$U/folders" | py 'import json,sys; print(next((f["fullName"] for f in json.load(sys.stdin) if f.get("specialUse")==sys.argv[1]), ""))' "$1"; }
# Quante mail con l'oggetto $2 ci sono nella cartella $1 (prima pagina).
count_subject() { curl -s -H "$H" "$U/folders/$(enc "$1")/messages?limit=50" | py 'import json,sys; print(sum(1 for m in json.load(sys.stdin)["items"] if m["subject"]==sys.argv[1]))' "$2"; }

ADDRESS=$(curl -s -H "$H" "$U/accounts" | py 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
DRAFTS=$(role drafts); SENT=$(role sent)
[ -n "$DRAFTS" ] && [ -n "$SENT" ] || { echo "Il server non dichiara Bozze o Posta inviata (SPECIAL-USE)."; exit 1; }
SUBJECT="PostinoVip prova bozza $(date '+%d/%m/%Y %H:%M:%S')"

echo "Account: $ADDRESS (Bozze: \"$DRAFTS\", Posta inviata: \"$SENT\")"
echo "La prova SALVA una bozza \"$SUBJECT\" in Bozze, la sostituisce, poi INVIA UNA MAIL a $ADDRESS"
echo "(solo a te) con invio differito di 20 secondi e copia in Posta inviata; la bozza viene eliminata."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

BODY=$(py 'import json,sys; print(json.dumps({"to": [sys.argv[1]], "subject": sys.argv[2], "body": "Prima versione",
  "htmlBody": "<p>Prima <strong>versione</strong></p>"}))' "$ADDRESS" "$SUBJECT")

echo "1. Bozza salvata e sostituita"
check "salvataggio: codice" "$(post /drafts "$BODY")" 200
UID1=$(field uid); check "sul server (non in attesa)" "$(field pending)" "False"
BODY2=$(py 'import json,sys; b=json.loads(sys.argv[1]); b["body"]="Seconda versione"; b["htmlBody"]="<p>Seconda <strong>versione</strong></p>"; b["replace"]={"uid": int(sys.argv[2])}; print(json.dumps(b))' "$BODY" "$UID1")
check "secondo salvataggio: codice" "$(post /drafts "$BODY2")" 200
UID2=$(field uid)
echo "         UID: $UID1 -> $UID2"
check "bozze con quell'oggetto in \"$DRAFTS\"" "$(count_subject "$DRAFTS" "$SUBJECT")" 1

echo "2. Riapertura come nell'app"
curl -s -H "$H" "$U/messages/$(enc "$DRAFTS")/$UID2/compose" > "$WORK/compose.json"
check "testo scritto separato" "$(py 'import json,sys; c=json.load(open(sys.argv[1])); print("sì" if "Seconda" in (c.get("html") or "") and c.get("quoteHtml") is None else "no")' "$WORK/compose.json")" "sì"
check "destinatario" "$(py 'import json,sys; print(json.load(open(sys.argv[1]))["to"][0])' "$WORK/compose.json")" "$ADDRESS"

echo "3. Invio differito di 20 secondi (Posta in uscita del computer)"
AFTER=$(py 'import datetime; print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(seconds=20)).isoformat())')
SEND=$(py 'import json,sys; b=json.loads(sys.argv[1]); b.pop("replace"); b["saveCopy"]=True; b["sendAfter"]=sys.argv[2]; b["deleteDraft"]={"uid": int(sys.argv[3])}; print(json.dumps(b))' "$BODY2" "$AFTER" "$UID2")
check "invio: codice" "$(post /send "$SEND")" 200
check "messa in coda" "$(field queued)" "True"
check "bozza eliminata subito" "$(count_subject "$DRAFTS" "$SUBJECT")" 0
check "nella Posta in uscita" "$(curl -s -H "$H" "$U/outbox" | py 'import json,sys; print(sum(1 for e in json.load(sys.stdin) if e["subject"]==sys.argv[1]))' "$SUBJECT")" 1
echo "         attesa dell'invio (al massimo 90 s)..."
for i in $(seq 90); do
  [ "$(curl -s -H "$H" "$U/outbox" | py 'import json,sys; print(len(json.load(sys.stdin)))')" = 0 ] && break
  sleep 1
done
check "Posta in uscita vuota" "$(curl -s -H "$H" "$U/outbox" | py 'import json,sys; print(len(json.load(sys.stdin)))')" 0
grep -E "Posta in uscita|bozza" "$WORK/core.log" | sed 's/^/         /' | head -5
check "copia in \"$SENT\"" "$(count_subject "$SENT" "$SUBJECT")" 1

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
echo "Controlla la mail \"$SUBJECT\" arrivata in INBOX; poi elimina mail e copia quando vuoi."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
