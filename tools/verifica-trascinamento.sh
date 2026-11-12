#!/usr/bin/env bash
# Verifica 3.5c (core): COPIA di mail e SPOSTAMENTO di cartelle sul SERVER VERO, account "main" (user-secrets).
# MODIFICA la casella, ma solo cartelle di prova create qui:
#   - crea "PostinoVip-prova" (con "Sotto") e "PostinoVip-prova-dest" (con una sua "Sotto");
#   - COPIA le 2 mail più recenti di INBOX in "PostinoVip-prova": gli originali NON vengono toccati
#     (la INBOX si apre in sola lettura, COPY non modifica i messaggi di origine);
#   - sposta "PostinoVip-prova" dentro "PostinoVip-prova-dest" e di nuovo in cima, prova gli errori;
#   - sposta "PostinoVip-prova/Sotto" in Posta eliminata;
#   - alla fine elimina DEFINITIVAMENTE le cartelle di prova, con le 2 copie.
# Nessun'altra mail o cartella viene toccata. Nessuna mail inviata. Chiede conferma prima di cominciare.
# Chiudere prima l'app (stessa copia locale di sviluppo, ~/.local/share/postinovip-dev).
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
DB=$HOME/.local/share/postinovip-dev/accounts/main/index.db
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-trascina-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero.
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Cache__Download__Enabled=false Api__Port=5097 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5097/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5097
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
field() { python3 -I -c 'import json,sys; v=json.loads(sys.argv[1]).get(sys.argv[2]); print("null" if v is None else (len(v) if isinstance(v, list) else v))' "$1" "$2"; }
enc() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
# Cartelle di prova sul server, in ordine.
test_folders() {
  curl -s -H "$H" "$U/folders" | python3 -I -c '
import json, sys
print(" ".join(sorted(f["fullName"] for f in json.load(sys.stdin) if "PostinoVip-prova" in f["fullName"])) or "-")'
}
# UID delle mail in una cartella (prima pagina, al massimo $2), separati da virgole.
uids() {
  curl -s -H "$H" "$U/folders/$(enc "$1")/messages?limit=$2" | python3 -I -c '
import json, sys
print(",".join(str(m["uid"]) for m in sorted(json.load(sys.stdin).get("items", []), key=lambda m: m["uid"])))'
}
count() { curl -s -H "$H" "$U/folders/$(enc "$1")/messages?limit=200" | python3 -I -c 'import json,sys; print(len(json.load(sys.stdin).get("items", [])))'; }
# id della cartella nella copia locale ("-" se non c'è).
cache_id() {
  python3 -I -c '
import sqlite3, sys
db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
row = db.execute("SELECT id FROM folders WHERE full_name = ?", (sys.argv[2],)).fetchone()
print(row[0] if row else "-")' "$DB" "$1"
}

ADDRESS=$(curl -s -H "$H" "$U/accounts" | python3 -I -c 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
EXISTING=$(test_folders)
if [ "$EXISTING" != "-" ]; then
  echo "Sul server ci sono già cartelle di prova ($EXISTING): toglierle prima di ripetere la prova."; exit 1
fi

echo "Account: $ADDRESS"
echo "La prova CREA cartelle PostinoVip-prova*, vi COPIA le 2 mail più recenti di INBOX (originali intatti),"
echo "SPOSTA le cartelle di prova e alla fine le ELIMINA definitivamente con le copie."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Cartelle di prova"
R=$(req POST /folders '{"name":"PostinoVip-prova"}');                          check "crea PostinoVip-prova" "${R%% *}" 201
R=$(req POST /folders '{"parent":"PostinoVip-prova","name":"Sotto"}');        check "crea PostinoVip-prova/Sotto" "${R%% *}" 201
R=$(req POST /folders '{"name":"PostinoVip-prova-dest"}');                     check "crea PostinoVip-prova-dest" "${R%% *}" 201
R=$(req POST /folders '{"parent":"PostinoVip-prova-dest","name":"Sotto"}');   check "crea PostinoVip-prova-dest/Sotto" "${R%% *}" 201

echo "2. Copia delle 2 mail più recenti di INBOX"
ORIG=$(uids INBOX 2)
echo "         UID in INBOX: $ORIG"
R=$(req POST /messages/INBOX/copy "{\"uids\":[$ORIG]}");                      check "senza destinazione" "${R%% *}" 400
R=$(req POST /messages/INBOX/copy "{\"uids\":[$ORIG],\"destination\":\"INBOX\"}"); check "nella stessa cartella" "${R%% *}" 409
R=$(req POST /messages/INBOX/copy "{\"uids\":[$ORIG,4000000000],\"destination\":\"PostinoVip-prova\"}")
check "copia: codice" "${R%% *}" 200
check "copia: mail trattate (UID inesistente ignorato)" "$(field "${R#* }" uids)" 2
check "copie in PostinoVip-prova" "$(count PostinoVip-prova)" 2
check "originali ancora in INBOX" "$(uids INBOX 200 | tr ',' '\n' | grep -cxF -e "${ORIG%,*}" -e "${ORIG#*,}")" 2

echo "3. Errori attesi (nessuna modifica)"
R=$(req POST /folders/INBOX/move '{"parent":"PostinoVip-prova"}');            check "sposta INBOX" "${R%% *}" 409
R=$(req POST /folders/PostinoVip-prova/move '{"parent":"PostinoVip-prova/Sotto"}'); check "dentro una sua sottocartella" "${R%% *}" 409
R=$(req POST /folders/PostinoVip-prova%2FSotto/move '{"parent":"PostinoVip-prova-dest"}'); check "nome già usato nella destinazione" "${R%% *}" 400
check "cartelle sul server" "$(test_folders)" "PostinoVip-prova PostinoVip-prova-dest PostinoVip-prova-dest/Sotto PostinoVip-prova/Sotto"

echo "4. Copia locale: Sotto sincronizzata"
R=$(req GET "/folders/PostinoVip-prova%2FSotto/messages?limit=1");            check "lista di Sotto" "${R%% *}" 200
ID=$(cache_id "PostinoVip-prova/Sotto");                                      echo "         id nella copia locale: $ID"

echo "5. Sposta PostinoVip-prova dentro PostinoVip-prova-dest, poi di nuovo in cima"
R=$(req POST /folders/PostinoVip-prova/move '{"parent":"PostinoVip-prova-dest"}')
check "spostata in" "$(field "${R#* }" fullName)" "PostinoVip-prova-dest/PostinoVip-prova"
check "copie spostate con la cartella" "$(count PostinoVip-prova-dest/PostinoVip-prova)" 2
check "copia locale: Sotto con lo stesso id" "$(cache_id "PostinoVip-prova-dest/PostinoVip-prova/Sotto")" "$ID"
R=$(req POST /folders/PostinoVip-prova-dest%2FPostinoVip-prova/move '{"parent":null}')
check "di nuovo in cima" "$(field "${R#* }" fullName)" "PostinoVip-prova"
R=$(req POST /folders/PostinoVip-prova/move '{}');                            check "già in cima: nessun cambiamento" "$(field "${R#* }" fullName)" "PostinoVip-prova"
check "cartelle sul server" "$(test_folders)" "PostinoVip-prova PostinoVip-prova-dest PostinoVip-prova-dest/Sotto PostinoVip-prova/Sotto"

echo "6. Sposta PostinoVip-prova/Sotto in Posta eliminata (nome libero se \"Sotto\" c'è già)"
R=$(req POST /folders/PostinoVip-prova%2FSotto/move '{"parent":"Posta eliminata"}')
TRASHED=$(field "${R#* }" fullName)
check "spostata in Posta eliminata" "${TRASHED%%/*}" "Posta eliminata"
check "copia locale: stesso id" "$(cache_id "$TRASHED")" "$ID"

echo "7. Pulizia: eliminazione definitiva delle cartelle di prova (e delle 2 copie)"
R=$(req DELETE "/folders/$(enc "$TRASHED")");                                check "$TRASHED definitiva" "$(field "${R#* }" permanent)" "True"
for F in PostinoVip-prova PostinoVip-prova-dest; do
  R=$(req DELETE "/folders/$F");                                              MOVED=$(field "${R#* }" movedTo)
  R=$(req DELETE "/folders/$(enc "$MOVED")");                                 check "$F definitiva" "$(field "${R#* }" permanent)" "True"
done
check "cartelle sul server" "$(test_folders)" "-"
check "originali ancora in INBOX" "$(uids INBOX 200 | tr ',' '\n' | grep -cxF -e "${ORIG%,*}" -e "${ORIG#*,}")" 2

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
