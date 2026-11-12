#!/usr/bin/env bash
# Verifica 4.1 (core): crittografia delle connessioni, autenticazione SMTP facoltativa, certificati di cui
# fidarsi. Usa POST /account/test, che fa SOLO collegamento e login (niente letture, niente invii, nessuna
# modifica alla casella), con l'indirizzo e la password degli user-secrets dell'account "main".
# Prove:
#   1. server di prova con varie porte e crittografie (alcune devono riuscire, altre fallire con un messaggio
#      chiaro; quelle "da vedere" dipendono da cosa offre il server);
#   2. server TLS locale con certificato autofirmato (openssl s_server): rifiutato prima del login con
#      l'impronta giusta, poi accettato indicando quell'impronta.
# La password non compare mai nel terminale né negli argomenti dei comandi (sta in un file 0600 temporaneo),
# e non viaggia mai in chiaro: le prove senza crittografia usano una password finta.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
command -v openssl >/dev/null || { echo "Serve openssl"; exit 1; }

WORK=$(mktemp -d -t postinovip-crittografia-XXXX)
chmod 700 "$WORK"
PID=; SPID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; [ -n "$SPID" ] && { kill $SPID 2>/dev/null; wait $SPID 2>/dev/null; }; rm -rf "$WORK"' EXIT

# Credenziali dagli user-secrets, in un file privato (mai sulla riga di comando).
(umask 077; dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" > "$WORK/secrets" 2>/dev/null)
grep -q '^Imap:Password' "$WORK/secrets" || { echo "User-secrets di main mancanti (Imap:Username / Imap:Password)"; exit 1; }
HOST=$(sed -n 's/^Imap:Host = //p' "$WORK/secrets")  # server di prova: negli user-secrets, non nel repository
[ -n "$HOST" ] || { echo "User-secrets: manca Imap:Host (server di prova): dotnet user-secrets set Imap:Host <server> --project core/src/PostinoVip.Api"; exit 1; }

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Cache__Download__Enabled=false Outbox__Enabled=false Api__Port=5097 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5097/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5097
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}

# prova IMAPHOST IMAPPORT IMAPSEC SMTPHOST SMTPPORT SMTPSEC AUTH [IMAPPIN] -> risposta in $WORK/r.json
prova() {
  python3 -I - "$WORK/secrets" "$WORK/req.json" "$@" <<'EOF'
import json, os, sys
secrets = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
a = sys.argv[3:]
# FINTA=1: password sbagliata di proposito (prove senza crittografia: la password vera non va mai in chiaro).
password = "password-finta-di-prova" if os.environ.get("FINTA") == "1" else secrets["Imap:Password"]
body = {"email": secrets["Imap:Username"], "password": password,
        "imapHost": a[0], "imapPort": int(a[1]), "imapSecurity": a[2],
        "smtpHost": a[3], "smtpPort": int(a[4]), "smtpSecurity": a[5], "smtpRequireAuth": a[6] == "true"}
if len(a) > 7: body["imapCertificateSha256"] = a[7]
fd = os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
os.write(fd, json.dumps(body).encode()); os.close(fd)
EOF
  curl -s -H "$H" -H "Content-Type: application/json" --data @"$WORK/req.json" "$U/account/test" > "$WORK/r.json"
}
# campo imap|smtp ok|error|sha
campo() {
  python3 -I -c '
import json, sys
r = json.load(open(sys.argv[1]))[sys.argv[2]]
v = {"ok": "riuscita" if r["ok"] else "fallita", "error": r.get("error") or "-",
     "sha": (r.get("certificate") or {}).get("sha256", "-")}[sys.argv[3]]
print(v)' "$WORK/r.json" "$1" "$2"
}
mostra() { # risultato informativo (dipende dal server)
  printf '  INFO   %s: %s (%s)\n' "$1" "$(campo "$2" ok)" "$(campo "$2" error)"
}

echo "1. Server di prova $HOST (solo collegamento e login)"
prova $HOST 993 SslOnConnect $HOST 587 StartTls true
check "IMAP 993 SSL/TLS" "$(campo imap ok)" riuscita
check "SMTP 587 STARTTLS" "$(campo smtp ok)" riuscita
prova $HOST 993 StartTls $HOST 587 SslOnConnect true
check "IMAP 993 con STARTTLS (sbagliata)" "$(campo imap ok)" fallita
echo "         messaggio: $(campo imap error)"
check "SMTP 587 con SSL/TLS (sbagliata)" "$(campo smtp ok)" fallita
echo "         messaggio: $(campo smtp error)"
prova $HOST 143 StartTls $HOST 465 SslOnConnect true
mostra "IMAP 143 STARTTLS" imap
mostra "SMTP 465 SSL/TLS (prima della 4.1 non funzionava)" smtp
prova $HOST 25 StartTls $HOST 25 StartTls false
mostra "SMTP 25 STARTTLS senza autenticazione" smtp
# Senza crittografia: con una password FINTA. "Autenticazione rifiutata" = collegamento in chiaro riuscito,
# il server ha risposto al login (con la password finta, che non serve a nessuno).
FINTA=1 prova $HOST 143 None $HOST 25 None false
mostra "IMAP 143 senza crittografia (password finta)" imap
mostra "SMTP 25 senza crittografia né autenticazione" smtp

echo "2. Server TLS locale con certificato autofirmato"
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=prova-postinovip.invalid" \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
SHA=$(openssl x509 -in "$WORK/cert.pem" -noout -fingerprint -sha256 | sed 's/.*=//; s/://g')
openssl s_server -quiet -accept 127.0.0.1:5098 -cert "$WORK/cert.pem" -key "$WORK/key.pem" < /dev/null > /dev/null 2>&1 &
SPID=$!
sleep 1
prova 127.0.0.1 5098 SslOnConnect 127.0.0.1 1 None true
check "autofirmato senza impronta" "$(campo imap ok)" fallita
check "impronta restituita = quella di openssl" "$(campo imap sha)" "$SHA"
echo "         messaggio: $(campo imap error)"
echo "         (il login non parte: il controllo del certificato avviene prima, test ConnectionSecurityTests)"
prova 127.0.0.1 5098 SslOnConnect 127.0.0.1 1 None true "$SHA"
check "con l'impronta: certificato accettato" "$(campo imap sha)" "-"
echo "         poi: $(campo imap error) (openssl non parla IMAP: atteso un errore di risposta, non di certificato)"

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
python3 -I -c '
import sys
secrets = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
sys.exit(1 if secrets["Imap:Password"] in open(sys.argv[2]).read() else 0)' "$WORK/secrets" "$WORK/core.log" \
  || { echo "ATTENZIONE: la password compare nel log del core"; exit 1; }
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
