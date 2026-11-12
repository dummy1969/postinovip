#!/usr/bin/env bash
# Verifica R1 (core): regole sulle mail nuove della Posta in arrivo, account "main" (user-secrets).
# MODIFICA LA CASELLA e INVIA DAVVERO UNA MAIL, solo all'indirizzo dell'account stesso:
#   1. crea la cartella "PostinoVip-regole";
#   2. salva una regola "oggetto contiene <codice della prova>" -> sposta lì, segna come letta, categoria verde,
#      più una regola che non deve scattare; le regole stanno in una cartella temporanea (non tocca le tue);
#   3. invia a te stesso una mail con quell'oggetto (senza copia in Posta inviata) e aspetta che l'IDLE la
#      segnali: la regola deve spostarla nella cartella di prova, letta e con la categoria;
#   4. R3 "Esegui regole ora": crea la sottocartella "PostinoVip-regole/Ora" ed esegue sulla cartella di prova
#      (sottocartelle comprese) una regola che sposta la mail lì e la contrassegna, seguendo l'avanzamento;
#   5. pulisce: elimina definitivamente la mail e la cartella di prova (passando da Posta eliminata).
# Nessun'altra mail viene toccata: le regole valgono solo per le mail arrivate dopo l'avvio.
# Chiede conferma prima di cominciare. Chiudere prima l'app.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-regole-XXXX)
chmod 700 "$WORK"
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# IDLE attivo (serve all'arrivo), copia locale e regole in una cartella temporanea.
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Cache__Directory="$WORK/cache" \
  Cache__Download__Enabled=false Outbox__Enabled=false Api__Port=5100 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5100/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5100
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}
py() { python3 -I -c "$1" "${@:2}"; }
req() { curl -s -o "$WORK/r.json" -w "%{http_code}" -X "$1" -H "$H" -H "Content-Type: application/json" ${3:+--data "$3"} "$U$2"; }
enc() { py 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
role() { curl -s -H "$H" "$U/folders" | py 'import json,sys; print(next((f["fullName"] for f in json.load(sys.stdin) if f.get("specialUse")==sys.argv[1]), ""))' "$1"; }
# La mail con l'oggetto $2 nella cartella $1: "uid seen categorie", vuoto se non c'è.
find_mail() { curl -s -H "$H" "$U/folders/$(enc "$1")/messages?limit=50" | py '
import json,sys
m = next((m for m in json.load(sys.stdin).get("items", []) if m["subject"] == sys.argv[1]), None)
print("" if m is None else f"{m['"'"'uid'"'"']} {m['"'"'seen'"'"']} {m.get('"'"'categories'"'"') or []}")' "$2"; }

ADDRESS=$(curl -s -H "$H" "$U/accounts" | py 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
TRASH=$(role trash)
[ -n "$TRASH" ] || { echo "Il server non dichiara Posta eliminata (SPECIAL-USE)."; exit 1; }
CODE=$(openssl rand -hex 4)
FOLDER="PostinoVip-regole"
SUBJECT="PostinoVip prova regole $CODE"

echo "Account: $ADDRESS"
echo "La prova CREA la cartella \"$FOLDER\", INVIA UNA MAIL a $ADDRESS (solo a te) con oggetto \"$SUBJECT\","
echo "controlla che la regola la sposti lì, poi ELIMINA DEFINITIVAMENTE la mail e la cartella di prova."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Cartella di prova e regole"
check "cartella creata" "$(req POST /folders "{\"name\":\"$FOLDER\"}")" 201
RULES=$(py 'import json,sys; print(json.dumps([
  {"name": "Prova regole", "conditions": {"subjectContains": [sys.argv[1]]},
   "actions": {"moveTo": sys.argv[2], "markRead": True, "category": 4, "stopProcessing": True}},
  {"name": "Non deve scattare", "conditions": {"subjectContains": ["parola-che-non-c-e-" + sys.argv[1]]}, "actions": {"flag": True}}]))' "$CODE" "$FOLDER")
check "regole salvate" "$(req PUT /rules "$RULES")" 200
for i in $(seq 100); do [ -f "$WORK/cache/accounts/main/rules-state.json" ] && break; sleep 0.2; done
check "punto di partenza fissato (mail già presenti non toccate)" "$([ -f "$WORK/cache/accounts/main/rules-state.json" ] && echo sì || echo no)" "sì"

echo "2. Invio a te stesso e arrivo (al massimo 2 minuti)"
SEND=$(py 'import json,sys; print(json.dumps({"to": [sys.argv[1]], "subject": sys.argv[2], "body": "Prova automatica delle regole di PostinoVip.", "saveCopy": False}))' "$ADDRESS" "$SUBJECT")
check "invio" "$(req POST /send "$SEND")" 200
FOUND=""
for i in $(seq 120); do
  FOUND=$(find_mail "$FOLDER" "$SUBJECT"); [ -n "$FOUND" ] && break; sleep 1
done
read -r MUID MSEEN MCATS <<< "$FOUND"
check "spostata nella cartella di prova" "$([ -n "$FOUND" ] && echo sì || echo no)" "sì"
check "non più in Posta in arrivo" "$([ -z "$(find_mail INBOX "$SUBJECT")" ] && echo sì || echo no)" "sì"
check "segnata come letta" "${MSEEN:-?}" "True"
check "categoria verde (4)" "${MCATS:-?}" "[4]"
grep -E "\[main\] regole" "$WORK/core.log" | sed 's/^.*\[main\]/         [main]/' | head -5
check "nel log nessun oggetto" "$(grep -c "$CODE" "$WORK/core.log")" 0

echo "3. Esegui regole ora sulla cartella di prova (sottocartelle comprese)"
SUB="$FOLDER/Ora"
check "sottocartella creata" "$(req POST /folders "{\"parent\":\"$FOLDER\",\"name\":\"Ora\"}")" 201
SUB=$(py 'import json,sys; print(json.load(open(sys.argv[1]))["fullName"])' "$WORK/r.json")
RULES2=$(py 'import json,sys; print(json.dumps([{"name": "Esegui ora", "enabled": False, "conditions": {"subjectContains": [sys.argv[1]]},
  "actions": {"moveTo": sys.argv[2], "flag": True}}]))' "$CODE" "$SUB")
check "regola salvata (disattivata: si esegue solo a mano)" "$(req PUT /rules "$RULES2")" 200
RID=$(py 'import json,sys; print(json.load(open(sys.argv[1]))[0]["id"])' "$WORK/r.json")
RUN=$(py 'import json,sys; print(json.dumps({"ruleIds": [sys.argv[1]], "folder": sys.argv[2], "includeSubfolders": True, "filter": "All"}))' "$RID" "$FOLDER")
check "esecuzione avviata" "$(req POST /rules/run "$RUN")" 202
JOB=$(py 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$WORK/r.json")
for i in $(seq 120); do
  req GET "/rules/run/$JOB" > /dev/null
  [ "$(py 'import json,sys; print(json.load(open(sys.argv[1]))["done"])' "$WORK/r.json")" = "True" ] && break; sleep 0.5
done
STATUS=$(py 'import json,sys; s=json.load(open(sys.argv[1])); print(s["checked"], s["applied"], s["failed"], s["error"])' "$WORK/r.json")
check "esaminate / modificate / errori" "$STATUS" "1 1 0 None"
FOUND2=$(find_mail "$SUB" "$SUBJECT")
check "spostata nella sottocartella" "$([ -n "$FOUND2" ] && echo sì || echo no)" "sì"
check "contrassegnata" "$(curl -s -H "$H" "$U/folders/$(enc "$SUB")/messages?limit=50" | py '
import json,sys
print(next((m["flagged"] for m in json.load(sys.stdin)["items"] if m["subject"] == sys.argv[1]), "?"))' "$SUBJECT")" "True"
[ -n "$FOUND2" ] && { MUID=$(echo "$FOUND2" | cut -d' ' -f1); FOLDER_OF_MAIL="$SUB"; }

echo "4. Pulizia"
if [ -n "${MUID:-}" ]; then
  check "mail in Posta eliminata" "$(req DELETE "/messages/$(enc "${FOLDER_OF_MAIL:-$FOLDER}")/$MUID")" 200
  TUID=$(find_mail "$TRASH" "$SUBJECT" | cut -d' ' -f1)
  [ -n "$TUID" ] && check "mail eliminata definitivamente" "$(req DELETE "/messages/$(enc "$TRASH")/$TUID?permanent=true")" 200
fi
check "cartella in Posta eliminata" "$(req DELETE "/folders/$(enc "$FOLDER")")" 200
MOVED=$(py 'import json,sys; print(json.load(open(sys.argv[1])).get("movedTo") or "")' "$WORK/r.json")
[ -n "$MOVED" ] && check "cartella eliminata definitivamente" "$(req DELETE "/folders/$(enc "$MOVED")")" 200

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
