#!/usr/bin/env bash
# Verifica 3.7b (core): invio di una mail FORMATTATA (HTML + testo) con citazione dell'originale,
# account "main" (user-secrets).
# INVIA DAVVERO UNA MAIL, solo all'indirizzo dell'account stesso, e ne salva la copia in Posta inviata.
#   - testo: grassetto, colore, elenco puntato, un collegamento e una piccola immagine incollata;
#   - citazione (come "Rispondi") della mail più recente di INBOX, ripresa dal core: l'originale non
#     viene toccato (lettura con BODY.PEEK, resta letta/non letta com'era).
# Nessun'altra modifica alla casella. La mail ricevuta e la copia restano: eliminale tu dopo averle viste.
# Chiede conferma prima di inviare. Chiudere prima l'app (stessa copia locale di sviluppo).
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-html-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero.
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Cache__Download__Enabled=false Api__Port=5098 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5098/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5098
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}
py() { python3 -I -c "$1" "${@:2}"; }

ADDRESS=$(curl -s -H "$H" "$U/accounts" | py 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
ORIG=$(curl -s -H "$H" "$U/folders/INBOX/messages?limit=1" | py 'import json,sys; i=json.load(sys.stdin)["items"]; print(i[0]["uid"] if i else "")')
[ -n "$ORIG" ] || { echo "INBOX vuota: serve una mail da citare."; exit 1; }
SEEN_BEFORE=$(curl -s -H "$H" "$U/folders/INBOX/messages?limit=1" | py 'import json,sys; print(json.load(sys.stdin)["items"][0]["seen"])')
SUBJECT="PostinoVip prova HTML $(date '+%d/%m/%Y %H:%M:%S')"

echo "Account: $ADDRESS"
echo "Verrà INVIATA una mail a $ADDRESS (solo a te), oggetto \"$SUBJECT\","
echo "con la citazione della mail più recente di INBOX (UID $ORIG, non modificata), e salvata in Posta inviata."
read -r -p "Inviare? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessun invio."; exit 0; }

# PNG 1x1 rosso: immagine "incollata" nel testo (data:), che il core trasforma in parte incorporata.
PNG="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
py '
import json, sys
address, subject, uid, png = sys.argv[1:5]
html = ("<div style=\"font-family:Calibri, Arial, sans-serif;font-size:11pt\">"
        "<p style=\"margin:0\">Prova di <strong>grassetto</strong> e <span style=\"color:#C00000\">rosso</span>.</p>"
        "<ul><li>primo punto</li><li>secondo punto</li></ul>"
        "<p style=\"margin:0\"><a href=\"https://example.com\">collegamento</a> e immagine: "
        f"<img src=\"data:image/png;base64,{png}\" style=\"max-width:100%\"></p></div>")
print(json.dumps({"to": [address], "subject": subject,
                  "body": "Prova di grassetto e rosso.\n- primo punto\n- secondo punto\ncollegamento e immagine: [immagine]",
                  "htmlBody": html, "quote": {"folder": "INBOX", "uid": int(uid), "mode": "reply"}, "saveCopy": True}))
' "$ADDRESS" "$SUBJECT" "$ORIG" "$PNG" > "$WORK/send.json"

echo "1. Invio"
CODE=$(curl -s -o "$WORK/sent.json" -w "%{http_code}" -X POST -H "$H" -H "Content-Type: application/json" --data @"$WORK/send.json" "$U/send")
check "codice" "$CODE" 200
SENT_FOLDER=$(py 'import json,sys; print(json.load(open(sys.argv[1])).get("savedTo") or "")' "$WORK/sent.json")
check "copia salvata" "$([ -n "$SENT_FOLDER" ] && echo sì || echo no)" "sì"
echo "         risposta del server: $(py 'import json,sys; print(json.load(open(sys.argv[1])).get("serverResponse"))' "$WORK/sent.json")"

echo "2. Copia in \"$SENT_FOLDER\" (come la vedranno i destinatari)"
ENC=$(py 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$SENT_FOLDER")
UID_SENT=$(curl -s -H "$H" "$U/folders/$ENC/messages?limit=20" | py '
import json, sys
print(next((str(m["uid"]) for m in json.load(sys.stdin)["items"] if m["subject"] == sys.argv[1]), ""))' "$SUBJECT")
check "copia trovata" "$([ -n "$UID_SENT" ] && echo sì || echo no)" "sì"
if [ -n "$UID_SENT" ]; then
  curl -s -H "$H" "$U/messages/$ENC/$UID_SENT" > "$WORK/detail.json"
  RES=$(py '
import json, sys
d = json.load(open(sys.argv[1])); h = d.get("htmlBody") or ""; t = d.get("textBody") or ""
print("sì" if "<strong>grassetto</strong>" in h else "no",
      "sì" if "<ul>" in h and "primo punto" in h else "no",
      "sì" if "color:#C00000" in h.replace(" ", "") or "color:#c00000" in h.replace(" ", "") else "no",
      "sì" if "data:image/png" in h else "no",
      "sì" if "Oggetto:" in h and "Da:" in h else "no",
      "sì" if "Prova di grassetto" in t and "ha scritto:" in t else "no",
      len(d.get("attachments", [])))' "$WORK/detail.json")
  read -r B L C I Q T A <<< "$RES"
  check "HTML: grassetto" "$B" "sì"
  check "HTML: elenco puntato" "$L" "sì"
  check "HTML: colore" "$C" "sì"
  check "HTML: immagine incorporata (cid, mostrata come data:)" "$I" "sì"
  check "HTML: citazione con Da/Oggetto" "$Q" "sì"
  check "testo: scritto + citazione (\"... ha scritto:\")" "$T" "sì"
  check "allegati (l'immagine è incorporata, non allegata)" "$A" "0"
fi

echo "3. Originale non toccato"
check "stato letto della mail citata" "$(curl -s -H "$H" "$U/folders/INBOX/messages?limit=1" | py 'import json,sys; print(json.load(sys.stdin)["items"][0]["seen"])')" "$SEEN_BEFORE"

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
echo "Apri la mail \"$SUBJECT\" anche con un altro programma (webmail, Thunderbird, Outlook) per vedere la formattazione."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
