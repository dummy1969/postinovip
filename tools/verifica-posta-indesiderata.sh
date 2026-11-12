#!/usr/bin/env bash
# Verifica J1 (core): posta indesiderata, account "main" (user-secrets).
# MODIFICA LA CASELLA (nessuna mail inviata):
#   1. crea la cartella "PostinoVip-indesiderata" e la sceglie come posta indesiderata (opzioni in una copia locale
#      temporanea: le tue non cambiano), livello «Bassa»;
#   2. aggiunge (IMAP APPEND, nessun invio) in Posta in arrivo due mail di prova da un mittente inventato
#      (@example.invalid): una segnata come spam (X-Spam-Flag: YES), una no; il filtro, svegliato dall'IDLE, deve
#      spostare solo la prima, con la parola chiave $Junk;
#   3. «Blocca mittente» sulla seconda (spostata lì, mittente tra i bloccati), poi «Non è posta indesiderata»
#      (di nuovo in Posta in arrivo, $NotJunk, mittente tra gli attendibili);
#   4. pulisce: elimina definitivamente le due mail e la cartella di prova (passando da Posta eliminata).
# Nessun'altra mail viene toccata: il filtro vale solo per le mail arrivate dopo l'avvio.
# Le parole chiave si leggono con un collegamento IMAP diretto in sola lettura (EXAMINE), credenziali da un file
# privato (0600, cancellato alla fine), mai sulla riga di comando né sullo schermo; certificato verificato.
# Chiede conferma prima di cominciare. Chiudere prima l'app. Mostra solo numeri, sì/no e nomi delle cartelle.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-indesiderata-XXXX)
chmod 700 "$WORK"
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

(umask 077; dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" > "$WORK/secrets" 2>/dev/null)
grep -q '^Imap:Password' "$WORK/secrets" || { echo "User-secrets di main mancanti (Imap:Username / Imap:Password)"; exit 1; }

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
# IDLE attivo (serve all'arrivo), copia locale e opzioni in una cartella temporanea.
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Cache__Directory="$WORK/cache" \
  Cache__Download__Enabled=false Outbox__Enabled=false Api__Port=5101 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5101/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5101
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}
py() { python3 -I -c "$1" "${@:2}"; }
req() { curl -s -o "$WORK/r.json" -w "%{http_code}" -X "$1" -H "$H" -H "Content-Type: application/json" ${3:+--data "$3"} "$U$2"; }
enc() { py 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
field() { py 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2]); print("null" if v is None else (",".join(map(str, v)) if isinstance(v, list) else v))' "$WORK/r.json" "$1"; }
role() { curl -s -H "$H" "$U/folders" | py 'import json,sys; print(next((f["fullName"] for f in json.load(sys.stdin) if f.get("specialUse")==sys.argv[1]), ""))' "$1"; }
uid_in() { curl -s -H "$H" "$U/folders/$(enc "$1")/messages?limit=50" | py 'import json,sys; print(next((m["uid"] for m in json.load(sys.stdin).get("items", []) if m["subject"]==sys.argv[1]), ""))' "$2"; }

# IMAP diretto: "append <oggetto> <mittente> <spam sì/no>" oppure "keywords <cartella> <oggetto>" (sola lettura).
imap() { python3 -I - "$WORK/secrets" "$@" <<'EOF'
import imaplib, ssl, sys, time, email.utils
secrets = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
host, port = secrets["Imap:Host"], int(secrets.get("Imap:Port", "993"))
context = ssl.create_default_context()
imap = imaplib.IMAP4_SSL(host, port, ssl_context=context) if port == 993 else imaplib.IMAP4(host, port)
if port != 993:
    imap.starttls(ssl_context=context)
imap.login(secrets["Imap:Username"], secrets["Imap:Password"])
if sys.argv[2] == "append":
    subject, sender, spam = sys.argv[3], sys.argv[4], sys.argv[5] == "sì"
    status = "Yes, score=9.9 required=5.0 tests=PROVA" if spam else "No, score=0.1 required=5.0 tests=PROVA"
    raw = (f"X-Spam-Flag: {'YES' if spam else 'NO'}\r\nX-Spam-Status: {status}\r\nFrom: Prova PostinoVip <{sender}>\r\n"
           f"To: {secrets['Imap:Username']}\r\nSubject: {subject}\r\nDate: {email.utils.formatdate(localtime=True)}\r\n"
           f"Message-ID: <{time.time_ns()}@example.invalid>\r\n\r\nMail di prova della posta indesiderata di PostinoVip.\r\n")
    typ, _ = imap.append("INBOX", None, None, raw.encode())
    print(typ)
else:
    folder, subject = sys.argv[3], sys.argv[4]
    imap.select(f'"{folder}"', readonly=True)  # EXAMINE
    _, data = imap.uid("SEARCH", "CHARSET", "UTF-8", "SUBJECT", subject.encode())
    uids = data[0].split()
    if not uids:
        print("assente")
    else:
        _, resp = imap.uid("FETCH", uids[-1], "(FLAGS)")
        flags = resp[0].decode() if isinstance(resp[0], bytes) else resp[0][0].decode()
        words = flags.split("FLAGS (", 1)[1].split(")", 1)[0].split()
        print(" ".join(sorted(w for w in words if w.lower() in ("$junk", "junk", "$notjunk", "nonjunk"))) or "nessuna")
imap.logout()
EOF
}

ADDRESS=$(curl -s -H "$H" "$U/accounts" | py 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
TRASH=$(role trash)
[ -n "$TRASH" ] || { echo "Il server non dichiara Posta eliminata (SPECIAL-USE)."; exit 1; }
CODE=$(openssl rand -hex 4)
FOLDER="PostinoVip-indesiderata"
S1="PostinoVip prova indesiderata $CODE spam"
S2="PostinoVip prova indesiderata $CODE normale"
SENDER="prova-$CODE@example.invalid"

echo "Account: $ADDRESS"
echo "La prova CREA la cartella \"$FOLDER\", AGGIUNGE in Posta in arrivo (APPEND, nessun invio) due mail di prova da"
echo "un mittente inventato, le sposta tra Posta in arrivo e la cartella di prova (con le parole chiave \$Junk/\$NotJunk),"
echo "poi ELIMINA DEFINITIVAMENTE le due mail e la cartella di prova. Le tue opzioni non cambiano."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Cartella e opzioni"
req GET /junk > /dev/null
BEFORE=$(field junkFolder)
echo "         posta indesiderata dell'account prima della prova: $BEFORE"
if [ "$BEFORE" = "null" ]; then
  check "senza cartella «Blocca mittente» rifiutato (nessuna modifica)" "$(req POST /messages/INBOX/block '{"uids":[1]}')" 409
fi
check "cartella creata" "$(req POST /folders "{\"name\":\"$FOLDER\"}")" 201
for i in $(seq 100); do [ -f "$WORK/cache/accounts/main/junk-state.json" ] && break; sleep 0.2; done
check "punto di partenza fissato (mail già presenti non toccate)" "$([ -f "$WORK/cache/accounts/main/junk-state.json" ] && echo sì || echo no)" "sì"
OPTIONS=$(py 'import json,sys; print(json.dumps({"level": "Low", "folder": sys.argv[1]}))' "$FOLDER")
check "opzioni salvate (livello Bassa, cartella di prova)" "$(req PUT /junk "$OPTIONS")" 200
check "cartella in uso" "$(field junkFolder)" "$FOLDER"
check "ruolo junk nell'elenco delle cartelle" "$(role junk)" "$FOLDER"

echo "2. Filtro sulle mail nuove (al massimo 2 minuti)"
check "mail segnata spam aggiunta" "$(imap append "$S1" "spam-$SENDER" sì)" OK
check "mail normale aggiunta" "$(imap append "$S2" "$SENDER" no)" OK
U1=""; U2=""
for i in $(seq 120); do
  U1=$(uid_in "$FOLDER" "$S1"); [ -n "$U1" ] && break; sleep 1
done
U2=$(uid_in INBOX "$S2")
check "spam spostata nella posta indesiderata" "$([ -n "$U1" ] && echo sì || echo no)" "sì"
check "mail normale rimasta in Posta in arrivo" "$([ -n "$U2" ] && echo sì || echo no)" "sì"
check "parole chiave della spam sul server" "$(imap keywords "$FOLDER" "$S1")" '$Junk Junk'
grep -E "\[main\] posta indesiderata" "$WORK/core.log" | sed 's/^.*\[main\]/         [main]/' | head -5

echo "3. Blocca mittente e Non è posta indesiderata"
if [ -n "$U2" ]; then
  check "blocca mittente" "$(req POST /messages/INBOX/block "{\"uids\":[$U2]}")" 200
  check "mittente tra i bloccati" "$(field entries)" "$SENDER"
  J2=$(uid_in "$FOLDER" "$S2")
  check "spostata nella posta indesiderata" "$([ -n "$J2" ] && echo sì || echo no)" "sì"
  check "parole chiave sul server" "$(imap keywords "$FOLDER" "$S2")" '$Junk Junk'
  if [ -n "$J2" ]; then
    check "non è posta indesiderata" "$(req POST "/messages/$(enc "$FOLDER")/not-junk" "{\"uids\":[$J2],\"trustSenders\":true}")" 200
    U2=$(uid_in INBOX "$S2")
    check "di nuovo in Posta in arrivo" "$([ -n "$U2" ] && echo sì || echo no)" "sì"
    check "parole chiave sul server" "$(imap keywords INBOX "$S2")" '$NotJunk NonJunk'
    req GET /junk > /dev/null
    check "mittente tra gli attendibili, non più tra i bloccati" "$(field safeSenders) / $(field blockedSenders)" "$SENDER / "
  fi
fi
check "nel log nessun oggetto né indirizzo di prova" "$(grep -c "$CODE" "$WORK/core.log")" 0

echo "4. Pulizia"
for pair in "$FOLDER|$S1" "INBOX|$S2" "$FOLDER|$S2"; do
  F=${pair%%|*}; S=${pair#*|}
  M=$(uid_in "$F" "$S"); [ -n "$M" ] || continue
  check "mail in Posta eliminata" "$(req DELETE "/messages/$(enc "$F")/$M")" 200
  T=$(uid_in "$TRASH" "$S")
  [ -n "$T" ] && check "mail eliminata definitivamente" "$(req DELETE "/messages/$(enc "$TRASH")/$T?permanent=true")" 200
done
check "cartella in Posta eliminata" "$(req DELETE "/folders/$(enc "$FOLDER")")" 200
MOVED=$(py 'import json,sys; print(json.load(open(sys.argv[1])).get("movedTo") or "")' "$WORK/r.json")
[ -n "$MOVED" ] && check "cartella eliminata definitivamente" "$(req DELETE "/folders/$(enc "$MOVED")")" 200

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
