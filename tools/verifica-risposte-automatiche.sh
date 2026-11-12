#!/usr/bin/env bash
# Verifica delle risposte automatiche (core), con due caselle vere: "main" (user-secrets) e un secondo account
# (indirizzo e password chiesti qui, la password senza mostrarla). INVIA DAVVERO DELLE MAIL:
#   1. attiva le risposte automatiche di main (impostazioni in una cartella temporanea: non tocca le tue);
#   2. dal secondo account invia a main una mail di prova: main deve rispondere da solo una volta;
#   3. invia una seconda mail dallo stesso mittente: nessuna seconda risposta (una per mittente);
#   4. pulisce: risposte automatiche spente, le due mail di prova (in main) e la risposta (nel secondo account)
#      eliminate definitivamente passando da Posta eliminata. Nessun'altra mail viene toccata.
# Chiede conferma prima di cominciare. Chiudere prima l'app.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
HOST=$(dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" 2>/dev/null | sed -n 's/^Imap:Host = //p')  # server di prova: negli user-secrets, non nel repository
[ -n "$HOST" ] || { echo "User-secrets: manca Imap:Host (server di prova): dotnet user-secrets set Imap:Host <server> --project core/src/PostinoVip.Api"; exit 1; }

WORK=$(mktemp -d -t postinovip-risposte-XXXX)
chmod 700 "$WORK"
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

(umask 077; dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" > "$WORK/secrets" 2>/dev/null)
grep -q '^Imap:Password' "$WORK/secrets" || { echo "User-secrets di main mancanti"; exit 1; }
read -r -p "Indirizzo del secondo account (sullo stesso server): " SECOND
[ -n "$SECOND" ] || { echo "Indirizzo vuoto: annullato."; exit 1; }
read -r -s -p "Password di $SECOND (non viene mostrata): " SECOND_PW; echo
[ -n "$SECOND_PW" ] || { echo "Password vuota: annullato."; exit 1; }

# Variabili dei due account in un file privato, caricate solo dal processo del core.
SECOND_PW="$SECOND_PW" python3 -I - "$WORK/secrets" "$WORK/env" "$HOST" "$SECOND" <<'EOF'
import os, shlex, sys
s = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
host, second = sys.argv[3], sys.argv[4]
v = {}
for i, (id_, user, pw) in enumerate([("main", s["Imap:Username"], s["Imap:Password"]), ("secondo", second, os.environ["SECOND_PW"])]):
    p = f"Accounts__{i}__"
    v.update({p + "Id": id_, p + "Imap__Host": host, p + "Imap__Port": "993", p + "Imap__Username": user,
              p + "Imap__Password": pw, p + "Smtp__Host": host, p + "Smtp__Port": "587"})
fd = os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
os.write(fd, "".join(f"export {k}={shlex.quote(x)}\n" for k, x in v.items()).encode()); os.close(fd)
EOF
unset SECOND_PW

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$ROOT/core/src/PostinoVip.Api" && . "$WORK/env" && exec env ASPNETCORE_ENVIRONMENT=Development Cache__Directory="$WORK/cache" \
  Cache__Download__Enabled=false Outbox__Enabled=false Api__Port=5101 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5101/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5101
OK=0; KO=0
check() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
          else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi; }
py() { python3 -I -c "$1" "${@:2}"; }
req() { curl -s -o "$WORK/r.json" -w "%{http_code}" -X "$1" -H "$H" -H "Content-Type: application/json" ${3:+--data "$3"} "$U$2"; }
enc() { py 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
trash() { curl -s -H "$H" "$U/accounts/$1/folders" | py 'import json,sys; print(next((f["fullName"] for f in json.load(sys.stdin) if f.get("specialUse")=="trash"), ""))'; }
# UID delle mail con oggetto $3 nella cartella $2 dell'account $1 (separati da spazi).
uids() { curl -s -H "$H" "$U/accounts/$1/folders/$(enc "$2")/messages?limit=50" | py '
import json,sys
print(" ".join(str(m["uid"]) for m in json.load(sys.stdin).get("items", []) if m["subject"] == sys.argv[1]))' "$3"; }

MAIN=$(curl -s -H "$H" "$U/accounts" | py 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$MAIN" ] || { echo "Core non avviato:"; tail -5 "$WORK/core.log"; exit 1; }
CODE=$(openssl rand -hex 4)
SUBJECT="PostinoVip prova risposta automatica $CODE"
REPLY="Risposta automatica: $SUBJECT"

echo "Account principale: $MAIN · secondo account: $SECOND"
echo "La prova ATTIVA le risposte automatiche di $MAIN, INVIA DUE MAIL da $SECOND a $MAIN e si aspetta"
echo "UNA risposta automatica; poi spegne le risposte ed ELIMINA DEFINITIVAMENTE le mail di prova."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Risposte automatiche di $MAIN attive"
AR=$(py 'import json; print(json.dumps({"enabled": True, "html": "<p>Prova automatica di <b>PostinoVip</b>: sono fuori sede.</p>", "text": "Prova automatica di PostinoVip: sono fuori sede."}))')
check "attivate" "$(req PUT /accounts/main/autoreply "$AR")" 200
check "attive adesso" "$(py 'import json,sys; print(json.load(open(sys.argv[1]))["active"])' "$WORK/r.json")" "True"
check "ora di attivazione salvata (si risponde solo alle mail che arrivano da adesso)" \
  "$(py 'import json,sys; print(json.load(open(sys.argv[1])).get("activatedAt") is not None)' "$WORK/cache/accounts/main/autoreply-state.json")" "True"

echo "2. Mail da $SECOND e risposta automatica (al massimo 2 minuti)"
MAIL=$(py 'import json,sys; print(json.dumps({"to": [sys.argv[1]], "subject": sys.argv[2], "body": "Prova delle risposte automatiche.", "saveCopy": False}))' "$MAIN" "$SUBJECT")
check "invio da $SECOND" "$(req POST /accounts/secondo/send "$MAIL")" 200
GOT=""
for i in $(seq 120); do GOT=$(uids secondo INBOX "$REPLY"); [ -n "$GOT" ] && break; sleep 1; done
check "risposta automatica arrivata a $SECOND" "$([ -n "$GOT" ] && echo sì || echo no)" "sì"
grep -E "\[main\] risposte automatiche" "$WORK/core.log" | sed 's/^.*\[main\]/         [main]/' | head -3

echo "3. Seconda mail dallo stesso mittente: nessuna seconda risposta"
MAIL2=$(py 'import json,sys; print(json.dumps({"to": [sys.argv[1]], "subject": sys.argv[2] + " (2)", "body": "Seconda prova.", "saveCopy": False}))' "$MAIN" "$SUBJECT")
check "seconda mail inviata" "$(req POST /accounts/secondo/send "$MAIL2")" 200
for i in $(seq 60); do [ -n "$(uids main INBOX "$SUBJECT (2)")" ] && break; sleep 1; done
sleep 20 # tempo per un'eventuale (sbagliata) seconda risposta
check "nessuna risposta alla seconda" "$(uids secondo INBOX "$REPLY (2)")" ""
check "nel log nessun indirizzo" "$(grep -c -i "$SECOND" "$WORK/core.log")" 0

echo "4. Pulizia"
OFF=$(py 'import json; print(json.dumps({"enabled": False, "html": "", "text": "x"}))')
check "risposte automatiche spente" "$(req PUT /accounts/main/autoreply "$OFF")" 200
for acc in main secondo; do
  T=$(trash $acc)
  for subj in "$SUBJECT" "$SUBJECT (2)" "$REPLY"; do
    for u in $(uids $acc INBOX "$subj"); do
      req DELETE "/accounts/$acc/messages/INBOX/$u" > /dev/null
    done
    for u in $(uids $acc "$T" "$subj"); do
      check "eliminata definitivamente ($acc)" "$(req DELETE "/accounts/$acc/messages/$(enc "$T")/$u?permanent=true")" 200
    done
  done
done

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
