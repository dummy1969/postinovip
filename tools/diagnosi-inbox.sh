#!/usr/bin/env bash
# Diagnosi: «The ImapClient is not connected» (HTTP 409) aprendo la Posta in arrivo di un account IMAP.
# SOLO LETTURA: nessuna modifica alla casella (cartelle aperte con EXAMINE, corpi con BODY.PEEK), nessun invio.
#   1. avvia il core di sviluppo su Linux con il solo account chiesto, in una copia locale temporanea (regole,
#      posta indesiderata, posta in uscita e IDLE spenti), e chiede la lista di Posta in arrivo e di Sent;
#   2. ripete a mano, con IMAP diretto, i comandi della sincronizzazione e ne misura i tempi.
# La password si scrive senza eco; passa al core solo per variabile d'ambiente e a Python da un file 0600,
# cancellati alla fine. Mostra solo numeri, tempi, nomi delle cartelle e messaggi d'errore (nessun contenuto).
# Va eseguito in un terminale vero (non con «!» da Claude Code: serve la tastiera per la password).
set -uo pipefail
trap 'echo "Errore alla riga $LINENO" >&2' ERR
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
[ -t 0 ] || { echo "Serve un terminale vero (per la password)."; exit 1; }

WORK=$(mktemp -d -t postinovip-diagnosi-XXXX)
chmod 700 "$WORK"
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

DEFHOST=$(dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" 2>/dev/null | sed -n 's/^Imap:Host = //p')
read -erp "Server IMAP [${DEFHOST}]: " HOST; HOST=${HOST:-$DEFHOST}
read -erp "Porta IMAP [993]: " PORT; PORT=${PORT:-993}
read -erp "Utente (indirizzo): " USER_NAME
read -rsp "Password (non si vede): " PASSWORD; echo
[ -n "$HOST" ] && [ -n "$USER_NAME" ] && [ -n "$PASSWORD" ] || { echo "Dati mancanti."; exit 1; }
# Un tasto accentato cancellato con il semplice read lascia mezzo carattere UTF-8 invisibile (successo il 12/11/2026).
for v in "$HOST" "$PORT" "$USER_NAME"; do
  [ "$(printf '%s' "$v" | LC_ALL=C tr -d '\040-\176' | wc -c)" -eq 0 ] || { echo "Server, porta o utente contengono caratteri non validi: riscriverli."; exit 1; }
done
printf '%s' "$PASSWORD" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 || { echo "La password contiene un carattere non valido: riscriverla."; exit 1; }
(umask 077; printf '%s\n%s\n%s\n%s\n' "$HOST" "$PORT" "$USER_NAME" "$PASSWORD" > "$WORK/cred")

echo
echo "== 1. Core vero (copia locale temporanea) =="
export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Production Cache__Directory="$WORK/cache" \
  Accounts__0__Id=diagnosi Accounts__0__Imap__Host="$HOST" Accounts__0__Imap__Port="$PORT" \
  Accounts__0__Imap__Username="$USER_NAME" Accounts__0__Imap__Password="$PASSWORD" \
  Accounts__0__Smtp__Host="$HOST" Accounts__0__Smtp__Port=587 \
  Outbox__Enabled=false Rules__Enabled=false Watch__Enabled=false CardDavSync__Enabled=false Pop3__Enabled=false \
  Logging__LogLevel__Default=Information Logging__LogLevel__Microsoft.AspNetCore=Warning \
  Api__Port=5103 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
unset PASSWORD
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5103/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5103
py() { python3 -I -c "$1" "${@:2}"; }
enc() { py 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
lista() { # lista <cartella>: codice HTTP, tempo, totale o errore
  local out
  out=$(curl -s -m 60 -o "$WORK/r.json" -w "%{http_code} %{time_total}" -H "$H" "$U/folders/$(enc "$1")/messages?limit=50")
  printf '  %-22s HTTP %s s  ' "$1" "$out"
  py 'import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: print("(risposta vuota)"); sys.exit()
print("totale %s, %d in pagina" % (d["total"], len(d["items"])) if "total" in d else "%s: %s" % (d.get("title"), d.get("detail")))' "$WORK/r.json"
}

code=$(curl -s -m 60 -o "$WORK/f.json" -w "%{http_code}" -H "$H" "$U/folders")
echo "  cartelle: HTTP $code"
SENT=$(py 'import json,sys
f=json.load(open(sys.argv[1])); print(next((x["fullName"] for x in f if x.get("specialUse")=="sent"), "Sent"))' "$WORK/f.json" 2>/dev/null || echo Sent)
lista INBOX
lista "$SENT"
lista INBOX
echo "  (attesa di 30 s per il download in background, poi di nuovo)"
sleep 30
lista INBOX
py 'import json,sys
d=json.load(open(sys.argv[1])); items=d.get("items", [])
print("  nella pagina: %d con allegati, %d senza, %d non ancora noti" % (sum(1 for m in items if m.get("hasAttachments") is True),
      sum(1 for m in items if m.get("hasAttachments") is False), sum(1 for m in items if m.get("hasAttachments") is None)))' "$WORK/r.json" 2>/dev/null || true
echo
echo "== 2. MailKit: struttura (BODYSTRUCTURE) di ogni mail di INBOX, una alla volta =="
dotnet run "$ROOT/tools/diagnosi-bodystructure.cs" -- "$WORK/cred" 2>&1 | tee "$WORK/bad.txt" | sed 's/^/  /'

echo
echo "== 2b. Risposta grezza del server per le mail con errore (testi oscurati) =="
python3 -I - "$WORK/cred" "$WORK/bad.txt" <<'EOF'
import imaplib, re, ssl, sys
host, port, user, pwd = open(sys.argv[1]).read().split("\n")[:4]
port = int(port)
bad = [l.split()[1] for l in open(sys.argv[2]) if l.startswith("BAD ")][:5]
if not bad:
    print("  nessuna mail con errore"); sys.exit()
ctx = ssl.create_default_context()
m = imaplib.IMAP4_SSL(host, port, ssl_context=ctx) if port == 993 else imaplib.IMAP4(host, port)
if port != 993:
    m.starttls(ssl_context=ctx)
m.login(user, pwd)
m.select("INBOX", readonly=True)
# Restano solo i nomi tecnici MIME: ogni altro testo (nomi dei file, indirizzi, oggetti, confini) diventa "x".
KEEP = set("""TEXT PLAIN HTML ENRICHED CALENDAR MULTIPART MIXED ALTERNATIVE RELATED REPORT SIGNED ENCRYPTED DIGEST
APPLICATION IMAGE AUDIO VIDEO MESSAGE RFC822 GLOBAL DELIVERY-STATUS DISPOSITION-NOTIFICATION OCTET-STREAM PDF ZIP
MS-TNEF PKCS7-SIGNATURE X-PKCS7-SIGNATURE PKCS7-MIME X-PKCS7-MIME PGP-SIGNATURE PGP-ENCRYPTED JPEG JPG PNG GIF BMP
CHARSET NAME FILENAME BOUNDARY FORMAT DELSP TYPE START METHOD REPORT-TYPE PROTOCOL MICALG SMIME-TYPE SIZE
CREATION-DATE MODIFICATION-DATE BASE64 QUOTED-PRINTABLE 7BIT 8BIT BINARY ATTACHMENT INLINE FLOWED
UTF-8 US-ASCII ISO-8859-1 ISO-8859-15 WINDOWS-1252 IT EN""".split())
def redact(b):
    out, i = [], 0
    while i < len(b):
        c = b[i:i+1]
        if c == b'"':
            j = i + 1
            while j < len(b) and b[j:j+1] != b'"':
                j += 2 if b[j:j+1] == b'\\' else 1
            word = b[i+1:j].decode("utf-8", "replace")
            out.append('"%s"' % word if word.upper() in KEEP else '"x"'); i = j + 1
        elif c == b'{' and re.match(rb'\{\d+\}\r\n', b[i:]):
            n = int(re.match(rb'\{(\d+)\}', b[i:]).group(1)); skip = b.index(b'\n', i) + 1
            out.append('{literal %d}' % n); i = skip + n
        else:
            out.append(c.decode("latin-1")); i += 1
    return "".join(out)
for uid in bad:
    typ, d = m.uid("FETCH", uid, "(BODYSTRUCTURE)")
    raw = b"".join(x[0] + x[1] if isinstance(x, tuple) else x for x in d if x)
    print(f"  UID {uid}:")
    print("    " + redact(raw))
m.logout()
EOF

echo "== 3. Log del core (righe di avviso, errore e cache) =="
grep -E -A3 "warn|fail|crit|cache|INBOX|Exception|->" "$WORK/core.log" | grep -v "Now listening" | sed 's/^/  /' | tail -80
echo
echo "Fine. Copia tutto l'output nella conversazione (non contiene password né contenuti delle mail)."
