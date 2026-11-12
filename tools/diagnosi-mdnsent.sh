#!/usr/bin/env bash
# Diagnosi R1: flag e parole chiave IMAP delle mail di prova di verifica-conferma-lettura.sh, così come le ha il
# server. SOLA LETTURA: EXAMINE (cartelle aperte in sola lettura) e BODY.PEEK; nessuna modifica, nessun invio.
# Collegamento diretto al server IMAP con le credenziali degli user-secrets di "main", lette da un file privato
# (0600, cancellato alla fine), mai sulla riga di comando né sullo schermo; certificato del server verificato.
# Mostra solo flag, parole chiave e gli oggetti delle mail cercate (predefinito: «PostinoVip prova conferma», le mail
# di prova; oppure l'oggetto dato come argomento) e, della richiesta di conferma (Disposition-Notification-To), solo
# se c'è e se coincide con il mittente: mai gli indirizzi. Dice anche se il nome di questo PC compare nelle righe
# Received: (nome con cui il programma si è presentato al server SMTP, EHLO).
# Uso: tools/diagnosi-mdnsent.sh ["parte dell'oggetto"]
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
WORK=$(mktemp -d -t postinovip-diagnosi-XXXX)
chmod 700 "$WORK"
trap 'rm -rf "$WORK"' EXIT

(umask 077; dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" > "$WORK/secrets" 2>/dev/null)
grep -q '^Imap:Password' "$WORK/secrets" || { echo "User-secrets di main mancanti (Imap:Username / Imap:Password)"; exit 1; }

python3 -I - "$WORK/secrets" "${1:-PostinoVip prova conferma}" <<'EOF'
import email, email.policy, email.utils, imaplib, re, socket, ssl, sys
pc = socket.gethostname().lower()
search = sys.argv[2]
secrets = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
host = secrets["Imap:Host"]
port = int(secrets.get("Imap:Port", "993"))
context = ssl.create_default_context()  # verifica del certificato e del nome, come il core
if port == 993:
    imap = imaplib.IMAP4_SSL(host, port, ssl_context=context)
else:
    imap = imaplib.IMAP4(host, port)
    imap.starttls(ssl_context=context)
imap.login(secrets["Imap:Username"], secrets["Imap:Password"])
print(f"Server: {host}:{port}")

# Tutte le cartelle (il server può non dichiarare \Trash): in ognuna si cercano le mail di prova.
_, folders = imap.list()
names = []
for line in folders:
    m = re.search(r'\(([^)]*)\) (?:"[^"]*"|NIL) (?:"((?:[^"\\]|\\.)*)"|(\S+))\s*$', line.decode(errors="replace"))
    if m and "\\Noselect" not in m.group(1):
        names.append(m.group(2) if m.group(2) is not None else m.group(3))

for name in names:
    typ, _ = imap.select(f'"{name}"', readonly=True)  # EXAMINE
    if typ != "OK":
        print(f"{name}: non aperta"); continue
    _, data = imap.uid("SEARCH", "CHARSET", "UTF-8", "SUBJECT", search.encode())
    uids = data[0].split()
    if not uids:
        continue
    print(f"\n{name}")
    for uid in uids[-12:]:
        _, resp = imap.uid("FETCH", uid, "(FLAGS BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DISPOSITION-NOTIFICATION-TO RECEIVED)])")
        meta = resp[0][0].decode(errors="replace") if isinstance(resp[0], tuple) else resp[0].decode(errors="replace")
        flags = re.search(r"FLAGS \(([^)]*)\)", meta)
        h = email.message_from_bytes(resp[0][1] if isinstance(resp[0], tuple) else b"", policy=email.policy.default)
        dnt = h["Disposition-Notification-To"]
        if dnt is None:
            request = "richiesta di conferma: assente"
        else:
            sender = h["From"].addresses[0].addr_spec.lower() if h["From"] and h["From"].addresses else ""
            addresses = [a for _, a in email.utils.getaddresses([str(dnt)]) if a]
            same = any(a.lower() == sender for a in addresses)
            request = f"richiesta di conferma: presente, {len(addresses)} indirizzi, uguale al mittente: {'sì' if same else 'no'}"
        if search.lower() not in str(h["Subject"] or "").lower():
            continue  # la ricerca del server è più larga (IceWarp: anche parole sparse); solo l'oggetto cercato
        received = h.get_all("Received") or []
        named = sum(1 for r in received if pc in str(r).lower())
        where = f"righe Received: {len(received)}, con il nome di questo PC: {named}"
        print(f"  uid {uid.decode():>6}  flag: ({flags.group(1) if flags else '?'})  {h['Subject']}  —  {request}; {where}")
imap.logout()
EOF
