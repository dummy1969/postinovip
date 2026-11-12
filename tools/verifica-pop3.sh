#!/usr/bin/env bash
# Verifica 4.2a (core): account POP3 sulla casella di prova (indirizzo e password degli user-secrets di "main").
# Cosa fa, dopo conferma:
#   - avvia il core di sviluppo con due account: "main" in IMAP (solo per contare le mail di INBOX prima e
#     dopo) e "pop3prova" in POP3 sulla 995, con "Lascia una copia sul server" e SENZA nessuna rimozione
#     (Rimuovi dopo N giorni = mai, Rimuovi quando eliminata = no): nessun DELE, nessuna mail tolta;
#   - il POP3 scarica TUTTA la Posta in arrivo del server in una cartella temporanea (può essere qualche
#     centinaio di MB e qualche minuto), poi controlla lista, lettura e ricerca dalla copia locale;
#   - riavvia il core: il secondo controllo non deve riscaricare niente;
#   - alla fine cancella la cartella temporanea.
# Possibile effetto sul server, da verificare: alcuni server segnano come lette in IMAP le mail scaricate con
# POP3. Lo script confronta le "da leggere" di INBOX prima e dopo e lo dice.
# La password non compare nel terminale né negli argomenti dei comandi (file 0600 temporaneo).
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
HOST=$(dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" 2>/dev/null | sed -n 's/^Imap:Host = //p')  # server di prova: negli user-secrets, non nel repository
[ -n "$HOST" ] || { echo "User-secrets: manca Imap:Host (server di prova): dotnet user-secrets set Imap:Host <server> --project core/src/PostinoVip.Api"; exit 1; }

echo "Questa verifica scarica con POP3 tutta la Posta in arrivo di $HOST in una cartella temporanea."
echo "Non toglie nessuna mail dal server; il server potrebbe segnarle come lette (lo script lo controlla)."
read -r -p "Procedere? Scrivi 'si' per continuare: " ANSWER
[ "$ANSWER" = "si" ] || { echo "Annullato."; exit 0; }

WORK=$(mktemp -d -t postinovip-pop3-XXXX)
chmod 700 "$WORK"
FREE=$(df -Pk "$WORK" | awk 'NR==2 {print $4}')
[ "$FREE" -gt 2000000 ] || { echo "Servono almeno 2 GB liberi in $WORK"; rm -rf "$WORK"; exit 1; }
PID=
stop_core() { [ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; PID=; }
trap 'stop_core; rm -rf "$WORK"' EXIT

(umask 077; dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" > "$WORK/secrets" 2>/dev/null)
grep -q '^Imap:Password' "$WORK/secrets" || { echo "User-secrets di main mancanti"; exit 1; }
# Variabili degli account in un file privato, caricate solo dal processo del core.
python3 -I - "$WORK/secrets" "$WORK/env" "$HOST" <<'EOF'
import os, shlex, sys
s = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
host = sys.argv[3]; user = s["Imap:Username"]; pw = s["Imap:Password"]
v = {
  "Accounts__0__Id": "main", "Accounts__0__Imap__Host": host, "Accounts__0__Imap__Port": "993",
  "Accounts__0__Imap__Username": user, "Accounts__0__Imap__Password": pw,
  "Accounts__0__Smtp__Host": host, "Accounts__0__Smtp__Port": "587",
  "Accounts__1__Id": "pop3prova", "Accounts__1__Type": "Pop3",
  "Accounts__1__Pop3__Host": host, "Accounts__1__Pop3__Port": "995", "Accounts__1__Pop3__Security": "SslOnConnect",
  "Accounts__1__Pop3__Username": user, "Accounts__1__Pop3__Password": pw,
  "Accounts__1__Pop3__LeaveOnServer": "true", "Accounts__1__Pop3__RemoveAfterDays": "0",
  "Accounts__1__Pop3__RemoveWhenDeleted": "false", "Accounts__1__Pop3__CheckMinutes": "60",
  "Accounts__1__Smtp__Host": host, "Accounts__1__Smtp__Port": "587",
}
fd = os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
os.write(fd, "".join(f"export {k}={shlex.quote(x)}\n" for k, x in v.items()).encode()); os.close(fd)
EOF

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5099
start_core() { # $1 = file di log, $2 = Pop3__Enabled (predefinito true)
  (cd "$ROOT/core/src/PostinoVip.Api" && . "$WORK/env" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
    Pop3__Enabled="${2:-true}" \
    Cache__Directory="$WORK/cache" Cache__Download__Enabled=false Outbox__Enabled=false Api__Port=5099 "$CORE" > "$1" 2>&1) &
  PID=$!
  for i in $(seq 50); do curl -s -o /dev/null $U/version && return 0; sleep 0.2; done
  echo "Core non avviato:"; tail -5 "$1"; exit 1
}
OK=0; KO=0
check() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
          else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi; }
inbox() { # $1 account, $2 count|unread
  curl -s -H "$H" "$U/accounts/$1/folders" | python3 -I -c '
import json, sys
f = [x for x in json.load(sys.stdin) if x.get("specialUse") == "inbox" or x["fullName"] == "INBOX"][0]
print(f.get(sys.argv[1]) if f.get(sys.argv[1]) is not None else "?")' "$2"
}

echo "0. INBOX in IMAP prima del POP3 (core senza POP3)"
start_core "$WORK/core0.log" false
IMAP_COUNT=$(inbox main count); IMAP_UNREAD=$(inbox main unread)
echo "         $IMAP_COUNT mail, $IMAP_UNREAD da leggere"
stop_core

echo "1. Primo avvio: scaricamento POP3 (al massimo 20 minuti)"
start_core "$WORK/core1.log"
for i in $(seq 1200); do
  grep -qE "pop3prova\] POP3: [0-9]+ sul server|pop3prova\] POP3: controllo non riuscito|POP3 non raggiungibile" "$WORK/core1.log" && break
  sleep 1
done
grep -E "pop3prova\] POP3" "$WORK/core1.log" | sed 's/^.*\(\[pop3prova\]\)/         \1/' | tail -8
RESULT=$(grep -oE "pop3prova\] POP3: [0-9]+ sul server, [0-9]+ scaricate" "$WORK/core1.log" | tail -1)
ON_SERVER=$(echo "$RESULT" | grep -oE "[0-9]+ sul server" | grep -oE "[0-9]+")
DOWNLOADED=$(echo "$RESULT" | grep -oE "[0-9]+ scaricate" | grep -oE "[0-9]+")
check "scaricate tutte quelle sul server" "${DOWNLOADED:-0}" "${ON_SERVER:-?}"
check "INBOX locale POP3 = mail sul server" "$(inbox pop3prova count)" "${ON_SERVER:-?}"
check "nessun errore dal server" "$(grep -c 'controllo non riuscito' "$WORK/core1.log")" 0

echo "2. Lettura dalla copia locale"
curl -s -H "$H" "$U/accounts/pop3prova/folders/INBOX/messages?limit=3" > "$WORK/page.json"
python3 -I - "$WORK/page.json" <<'EOF'
import json, sys
p = json.load(open(sys.argv[1]))
print(f"         prime 3 di {p['total']}:")
for m in p["items"]:
    print(f"           - {(m['date'] or '')[:16]:16}  {m['from'][:30]:30}  {m['subject'][:60]}")
EOF
UID1=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["items"][0]["uid"])' "$WORK/page.json")
WORD=$(python3 -I -c '
import json, re, sys
s = json.load(open(sys.argv[1]))["items"][0]["subject"]
w = [x for x in re.findall(r"\w{5,}", s)]
print(w[0] if w else "")' "$WORK/page.json")
check "apertura della più recente" "$(curl -s -o /dev/null -w '%{http_code}' -H "$H" "$U/accounts/pop3prova/messages/INBOX/$UID1")" 200
if [ -n "$WORD" ]; then
  HITS=$(curl -s -H "$H" "$U/accounts/pop3prova/search?q=$WORD" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["total"] > 0)')
  check "ricerca di \"$WORD\" nella copia POP3" "$HITS" True
fi
check "segna come letta (solo sul computer)" "$(curl -s -o /dev/null -w '%{http_code}' -X PUT -H "$H" -H 'Content-Type: application/json' \
  -d '{"seen":true}' "$U/accounts/pop3prova/messages/INBOX/$UID1/seen")" 200
check "\"Ricostruisci cache\" rifiutato per POP3" "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" "$U/accounts/pop3prova/cache/rebuild")" 409
stop_core

echo "3. Secondo avvio: niente da riscaricare"
start_core "$WORK/core2.log"
sleep 15
check "nuove mail scaricate al secondo controllo" "$(grep -oE 'pop3prova\] POP3: [0-9]+ sul server, [0-9]+ scaricate' "$WORK/core2.log" | grep -oE '[0-9]+ scaricate' | grep -oE '[0-9]+' || echo 0)" 0
check "INBOX locale invariata" "$(inbox pop3prova count)" "${ON_SERVER:-?}"
check "letto rimasto sul computer" "$(curl -s -H "$H" "$U/accounts/pop3prova/folders/INBOX/messages?limit=1" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["items"][0]["seen"])')" True

echo "4. Server (IMAP) dopo il POP3"
check "INBOX in IMAP: nessuna mail tolta" "$(inbox main count)" "$IMAP_COUNT"
AFTER_UNREAD=$(inbox main unread)
if [ "$AFTER_UNREAD" = "$IMAP_UNREAD" ]; then echo "  INFO   da leggere in IMAP invariate ($AFTER_UNREAD): il POP3 non le segna lette"
else echo "  INFO   da leggere in IMAP: prima $IMAP_UNREAD, dopo $AFTER_UNREAD (il server segna lette le mail scaricate con POP3)"; fi
echo "         spazio della copia POP3: $(du -sh "$WORK/cache/accounts/pop3prova/mail" | cut -f1)"
stop_core

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti. (cartella temporanea cancellata)"
python3 -I -c '
import sys
s = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
logs = open(sys.argv[2]).read() + open(sys.argv[3]).read()
sys.exit(1 if s["Imap:Password"] in logs else 0)' "$WORK/secrets" "$WORK/core1.log" "$WORK/core2.log" \
  || { echo "ATTENZIONE: la password compare nel log del core"; exit 1; }
[ "$KO" -eq 0 ] || exit 1
