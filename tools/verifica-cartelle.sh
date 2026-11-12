#!/usr/bin/env bash
# Verifica 3.4b (core): crea, rinomina ed elimina cartelle sul SERVER VERO, account "main" (user-secrets).
# MODIFICA la casella, ma solo cartelle di prova: "PostinoVip-prova" (con la sottocartella "Sotto"),
# poi rinominata "PostinoVip-prova-2", spostata in Posta eliminata e infine eliminata definitivamente.
# Nessun'altra cartella e nessuna mail vengono toccate. Chiede conferma prima di cominciare.
# Usa la copia locale di sviluppo (~/.local/share/postinovip-dev) per controllare che le cartelle
# rinominate mantengano il loro id (mail non riscaricate): chiudere prima l'app.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
DB=$HOME/.local/share/postinovip-dev/accounts/main/index.db
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-cartelle-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# exec: il PID in background è quello del core, così kill lo chiude davvero.
# Niente IDLE né download in background: solo i comandi di questa prova.
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
# req METODO percorso [json] -> stampa "codice corpo"
req() {
  local args=(-s -o "$WORK/body" -w "%{http_code}" -X "$1" -H "$H")
  [ $# -ge 3 ] && args+=(-H "Content-Type: application/json" -d "$3")
  local code; code=$(curl "${args[@]}" "$U$2"); echo "$code $(cat "$WORK/body")"
}
field() { python3 -I -c 'import json,sys; v=json.loads(sys.argv[1]).get(sys.argv[2]); print("null" if v is None else v)' "$1" "$2"; }
# Cartelle di prova sul server, una per riga.
test_folders() {
  curl -s -H "$H" "$U/folders" | python3 -I -c '
import json, sys
print(" ".join(sorted(f["fullName"] for f in json.load(sys.stdin) if "PostinoVip-prova" in f["fullName"])) or "-")'
}
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
echo "La prova CREA, RINOMINA ed ELIMINA (alla fine definitivamente) solo le cartelle PostinoVip-prova*."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Crea PostinoVip-prova e la sottocartella Sotto"
R=$(req POST /folders '{"name":"PostinoVip-prova"}');                     check "crea in cima" "${R%% *}" 201
R=$(req POST /folders '{"parent":"PostinoVip-prova","name":"Sotto"}');   check "crea sottocartella" "$(field "${R#* }" fullName)" "PostinoVip-prova/Sotto"
check "cartelle sul server" "$(test_folders)" "PostinoVip-prova PostinoVip-prova/Sotto"

echo "2. Errori attesi (nessuna modifica)"
R=$(req POST /folders '{"name":"postinovip-prova"}');                    check "nome già usato (maiuscole diverse)" "${R%% *}" 400
R=$(req POST /folders '{"name":"a/b"}');                                 check "nome con il separatore" "${R%% *}" 400
R=$(req POST /folders/INBOX/rename '{"name":"Altro"}');                  check "rinomina INBOX" "${R%% *}" 409
R=$(req DELETE "/folders/Posta%20eliminata");                            check "elimina Posta eliminata" "${R%% *}" 409

echo "3. Copia locale: la sottocartella viene sincronizzata"
R=$(req GET "/folders/PostinoVip-prova%2FSotto/messages?limit=1");      check "lista di Sotto" "${R%% *}" 200
ID=$(cache_id "PostinoVip-prova/Sotto");                                 echo "         id nella copia locale: $ID"

echo "4. Rinomina PostinoVip-prova -> PostinoVip-prova-2"
R=$(req POST /folders/PostinoVip-prova/rename '{"name":"PostinoVip-prova-2"}'); check "rinomina" "$(field "${R#* }" fullName)" "PostinoVip-prova-2"
check "cartelle sul server" "$(test_folders)" "PostinoVip-prova-2 PostinoVip-prova-2/Sotto"
check "copia locale: Sotto con lo stesso id" "$(cache_id "PostinoVip-prova-2/Sotto")" "$ID"

echo "5. Elimina: spostata in Posta eliminata"
R=$(req DELETE /folders/PostinoVip-prova-2);                             check "spostata in" "$(field "${R#* }" movedTo)" "Posta eliminata/PostinoVip-prova-2"
check "cartelle sul server" "$(test_folders)" "Posta eliminata/PostinoVip-prova-2 Posta eliminata/PostinoVip-prova-2/Sotto"
check "copia locale: Sotto con lo stesso id" "$(cache_id "Posta eliminata/PostinoVip-prova-2/Sotto")" "$ID"

echo "6. Elimina di nuovo, da dentro Posta eliminata: definitiva"
R=$(req DELETE "/folders/Posta%20eliminata%2FPostinoVip-prova-2");       check "definitiva" "$(field "${R#* }" permanent)" "True"
check "cartelle sul server" "$(test_folders)" "-"
check "copia locale: Sotto tolta" "$(cache_id "Posta eliminata/PostinoVip-prova-2/Sotto")" "-"

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
