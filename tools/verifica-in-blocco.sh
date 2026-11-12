#!/usr/bin/env bash
# Verifica 3.5a (core): operazioni IN BLOCCO sul SERVER VERO, account "main" (user-secrets).
# MODIFICA la casella, ma solo mail e cartelle di prova create qui:
#   - INVIA 3 mail all'indirizzo dell'account stesso (oggetto "PostinoVip prova in blocco <ora> n/3");
#   - le segna lette, aggiunge contrassegno e categoria rossa, le sposta nella cartella
#     "PostinoVip-prova", poi in Posta eliminata e infine le elimina DEFINITIVAMENTE;
#   - elimina la cartella di prova (in Posta eliminata, poi definitivamente).
# Nessun'altra mail o cartella viene toccata. Chiede conferma prima di cominciare.
# Chiudere prima l'app (stessa copia locale di sviluppo).
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-blocco-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero.
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
# req METODO percorso [json] -> "codice corpo"
req() {
  local args=(-s -o "$WORK/body" -w "%{http_code}" -X "$1" -H "$H")
  [ $# -ge 3 ] && args+=(-H "Content-Type: application/json" -d "$3")
  local code; code=$(curl "${args[@]}" "$U$2"); echo "$code $(cat "$WORK/body")"
}
# Mail di prova in una cartella (codificata per l'URL): "uid:letta:contrassegno:categorie" per riga, in ordine di UID.
state() {
  curl -s -H "$H" "$U/folders/$1/messages?limit=200" | python3 -I -c '
import json, sys
items = [m for m in json.load(sys.stdin).get("items", []) if sys.argv[1] in (m.get("subject") or "")]
for m in sorted(items, key=lambda m: m["uid"]):
    print("%d:%s:%s:%s" % (m["uid"], "letta" if m["seen"] else "da-leggere", "contrassegno" if m.get("flagged") else "-",
                          ",".join(map(str, m.get("categories") or [])) or "-"))' "$TAG"
}
count() { state "$1" | grep -c . ; }
uids_json() { state "$1" | cut -d: -f1 | paste -sd, | sed 's/^/[/; s/$/]/'; }
summary() { state "$1" | cut -d: -f2- | sort | uniq -c | sed 's/^ *//' | paste -sd' '; }

ADDRESS=$(curl -s -H "$H" "$U/accounts" | python3 -I -c 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
if curl -s -H "$H" "$U/folders" | grep -q '"PostinoVip-prova'; then
  echo "Sul server c'è già una cartella PostinoVip-prova*: toglierla prima di ripetere la prova."; exit 1
fi
TAG="PostinoVip prova in blocco $(date +%H%M%S)"

echo "Account: $ADDRESS"
echo "La prova INVIA 3 mail a $ADDRESS (oggetto \"$TAG n/3\"), le modifica e alla fine le ELIMINA"
echo "definitivamente, con la cartella PostinoVip-prova. Nessun'altra mail viene toccata."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Invio di 3 mail a sé stessi e attesa dell'arrivo in INBOX"
for n in 1 2 3; do
  R=$(req POST /send "{\"to\":[\"$ADDRESS\"],\"subject\":\"$TAG $n/3\",\"body\":\"Mail di prova di PostinoVip (operazioni in blocco): verrà eliminata dalla prova stessa.\"}")
  check "invio $n/3" "${R%% *}" 200
done
for i in $(seq 30); do [ "$(count INBOX)" = 3 ] && break; sleep 2; done
check "arrivate in INBOX" "$(count INBOX)" 3
UIDS=$(uids_json INBOX)
echo "         UID: $UIDS"

echo "2. Letto, contrassegno e categoria rossa in blocco (più un UID inesistente, ignorato)"
FAKE='4000000000'
R=$(req PUT /messages/INBOX/seen "{\"uids\":${UIDS%]},$FAKE],\"seen\":true}")
check "letto: mail trattate" "$(python3 -I -c 'import json,sys; print(len(json.loads(sys.argv[1])["uids"]))' "${R#* }")" 3
R=$(req PUT /messages/INBOX/flags "{\"uids\":$UIDS,\"followUp\":\"flagged\",\"addCategories\":[1]}")
check "contrassegno e categoria" "${R%% *}" 200
check "stato in INBOX" "$(summary INBOX)" "3 letta:contrassegno:1"

echo "3. Sposta in blocco nella cartella PostinoVip-prova"
R=$(req POST /folders '{"name":"PostinoVip-prova"}');                     check "cartella creata" "${R%% *}" 201
R=$(req POST /messages/INBOX/move "{\"uids\":$UIDS,\"destination\":\"PostinoVip-prova\"}")
check "spostate in" "$(python3 -I -c 'import json,sys; print(json.loads(sys.argv[1])["movedTo"])' "${R#* }")" "PostinoVip-prova"
check "rimaste in INBOX" "$(count INBOX)" 0
check "stato in PostinoVip-prova" "$(summary PostinoVip-prova)" "3 letta:contrassegno:1"

echo "4. Elimina in blocco: in Posta eliminata, poi definitiva"
P_UIDS=$(uids_json PostinoVip-prova)
R=$(req POST /messages/PostinoVip-prova/delete "{\"uids\":$P_UIDS}")
check "spostate in" "$(python3 -I -c 'import json,sys; print(json.loads(sys.argv[1])["movedTo"])' "${R#* }")" "Posta eliminata"
T_UIDS=$(uids_json "Posta%20eliminata")
check "in Posta eliminata" "$(count "Posta%20eliminata")" 3
R=$(req POST "/messages/Posta%20eliminata/delete" "{\"uids\":$T_UIDS,\"permanent\":true}")
check "eliminate definitivamente" "$(python3 -I -c 'import json,sys; print(len(json.loads(sys.argv[1])["uids"]))' "${R#* }")" 3
check "rimaste in Posta eliminata" "$(count "Posta%20eliminata")" 0

echo "5. Pulizia: cartella di prova eliminata"
R=$(req DELETE /folders/PostinoVip-prova);                               check "cartella in Posta eliminata" "${R%% *}" 200
R=$(req DELETE "/folders/Posta%20eliminata%2FPostinoVip-prova");         check "cartella eliminata" "${R%% *}" 200

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
