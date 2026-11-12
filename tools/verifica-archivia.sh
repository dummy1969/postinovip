#!/usr/bin/env bash
# Verifica A1 (core): Archivia, account "main" (user-secrets).
# MODIFICA LA CASELLA (nessuna mail inviata):
#   1. crea la cartella "PostinoVip-archivio" e la sceglie come cartella di archiviazione (scelta in una copia locale
#      temporanea: la tua non cambia; la tua cartella Archivio non viene toccata);
#   2. aggiunge (IMAP APPEND, nessun invio) in Posta in arrivo due mail di prova da un mittente inventato
#      (@example.invalid), una già letta e una no, e le archivia: devono finire nella cartella di prova con lo stato
#      letto/non letto di prima;
#   3. pulisce: elimina definitivamente le due mail e la cartella di prova (passando da Posta eliminata).
# Nessun'altra mail viene toccata. Credenziali da un file privato (0600, cancellato alla fine), mai sulla riga di
# comando né sullo schermo; certificato verificato. Chiede conferma prima di cominciare. Chiudere prima l'app.
# Mostra solo numeri, sì/no e nomi delle cartelle.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-archivia-XXXX)
chmod 700 "$WORK"
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

(umask 077; dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" > "$WORK/secrets" 2>/dev/null)
grep -q '^Imap:Password' "$WORK/secrets" || { echo "User-secrets di main mancanti (Imap:Username / Imap:Password)"; exit 1; }

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Cache__Directory="$WORK/cache" \
  Cache__Download__Enabled=false Outbox__Enabled=false Rules__Enabled=false Api__Port=5102 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5102/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5102
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
# "uid" o "seen" della mail con l'oggetto dato nella cartella ("" se non c'è).
msg() { curl -s -H "$H" "$U/folders/$(enc "$1")/messages?limit=50" | py 'import json,sys; m=next((m for m in json.load(sys.stdin).get("items", []) if m["subject"]==sys.argv[1]), None); print("" if m is None else (m["uid"] if sys.argv[2]=="uid" else ("sì" if m["seen"] else "no")))' "$2" "$3"; }

# IMAP diretto: "append <oggetto> <mittente> <letta sì/no>".
imap() { python3 -I - "$WORK/secrets" "$@" <<'EOF'
import imaplib, ssl, sys, time, email.utils
secrets = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
host, port = secrets["Imap:Host"], int(secrets.get("Imap:Port", "993"))
context = ssl.create_default_context()
imap = imaplib.IMAP4_SSL(host, port, ssl_context=context) if port == 993 else imaplib.IMAP4(host, port)
if port != 993:
    imap.starttls(ssl_context=context)
imap.login(secrets["Imap:Username"], secrets["Imap:Password"])
subject, sender, seen = sys.argv[3], sys.argv[4], sys.argv[5] == "sì"
raw = (f"From: Prova PostinoVip <{sender}>\r\nTo: {secrets['Imap:Username']}\r\nSubject: {subject}\r\n"
       f"Date: {email.utils.formatdate(localtime=True)}\r\nMessage-ID: <{time.time_ns()}@example.invalid>\r\n\r\n"
       f"Mail di prova di Archivia di PostinoVip.\r\n")
typ, _ = imap.append("INBOX", "(\\Seen)" if seen else None, None, raw.encode())
print(typ)
imap.logout()
EOF
}

ADDRESS=$(curl -s -H "$H" "$U/accounts" | py 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
TRASH=$(role trash)
[ -n "$TRASH" ] || { echo "Il server non dichiara Posta eliminata (SPECIAL-USE)."; exit 1; }
CODE=$(openssl rand -hex 4)
FOLDER="PostinoVip-archivio"
S1="PostinoVip prova archivia $CODE letta"
S2="PostinoVip prova archivia $CODE da leggere"
SENDER="prova-$CODE@example.invalid"

echo "Account: $ADDRESS"
echo "La prova CREA la cartella \"$FOLDER\", AGGIUNGE in Posta in arrivo (APPEND, nessun invio) due mail di prova da"
echo "un mittente inventato, le ARCHIVIA nella cartella di prova, poi ELIMINA DEFINITIVAMENTE le due mail e la cartella."
echo "La tua scelta della cartella di archiviazione non cambia."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Scelta della cartella"
check "prima della scelta: nessuna cartella" "$(req GET /archive; echo -n " "; field folder)" "200 null"
echo "         proposta per la prima volta: $(field suggested)"
check "senza scelta «Archivia» rifiutato (nessuna modifica)" "$(req POST /messages/INBOX/archive '{"uids":[1]}')" 409
check "nessun ruolo archive prima della scelta" "$(role archive)" ""
check "cartella di prova creata" "$(req POST /folders "{\"name\":\"$FOLDER\"}")" 201
check "Posta in arrivo rifiutata come archivio" "$(req PUT /archive '{"folder":"INBOX"}')" 400
check "cartella di prova scelta" "$(req PUT /archive "$(py 'import json,sys; print(json.dumps({"folder": sys.argv[1]}))' "$FOLDER")")" 200
check "ruolo archive nell'elenco delle cartelle" "$(role archive)" "$FOLDER"

echo "2. Archivia"
check "mail già letta aggiunta" "$(imap append "$S1" "$SENDER" sì)" OK
check "mail da leggere aggiunta" "$(imap append "$S2" "$SENDER" no)" OK
U1=""; U2=""
for i in $(seq 30); do
  U1=$(msg INBOX "$S1" uid); U2=$(msg INBOX "$S2" uid); [ -n "$U1" ] && [ -n "$U2" ] && break; sleep 1
done
check "mail di prova in Posta in arrivo" "$([ -n "$U1" ] && [ -n "$U2" ] && echo sì || echo no)" "sì"
if [ -n "$U1" ] && [ -n "$U2" ]; then
  check "archivia le due mail" "$(req POST /messages/INBOX/archive "{\"uids\":[$U1,$U2]}")" 200
  check "destinazione" "$(field movedTo)" "$FOLDER"
  check "mail spostate" "$(py 'import json,sys; print(len(json.load(open(sys.argv[1]))["uids"]))' "$WORK/r.json")" 2
  check "non più in Posta in arrivo" "$(msg INBOX "$S1" uid)$(msg INBOX "$S2" uid)" ""
  check "nell'archivio, letta resta letta" "$(msg "$FOLDER" "$S1" seen)" "sì"
  check "nell'archivio, da leggere resta da leggere" "$(msg "$FOLDER" "$S2" seen)" "no"
  A1=$(msg "$FOLDER" "$S1" uid)
  [ -n "$A1" ] && check "dall'archivio stesso rifiutato" "$(req POST "/messages/$(enc "$FOLDER")/archive" "{\"uids\":[$A1]}")" 409
fi
grep -E "\[main\] ARCHIVIA" "$WORK/core.log" | sed 's/^.*\[main\]/         [main]/' | head -3
check "nel log nessun oggetto né indirizzo di prova" "$(grep -c "$CODE" "$WORK/core.log")" 0

echo "3. Pulizia"
for pair in "$FOLDER|$S1" "$FOLDER|$S2" "INBOX|$S1" "INBOX|$S2"; do
  F=${pair%%|*}; S=${pair#*|}
  M=$(msg "$F" "$S" uid); [ -n "$M" ] || continue
  check "mail in Posta eliminata" "$(req DELETE "/messages/$(enc "$F")/$M")" 200
  T=$(msg "$TRASH" "$S" uid)
  [ -n "$T" ] && check "mail eliminata definitivamente" "$(req DELETE "/messages/$(enc "$TRASH")/$T?permanent=true")" 200
done
check "scelta tolta" "$(req PUT /archive '{"folder":null}')" 200
check "cartella in Posta eliminata" "$(req DELETE "/folders/$(enc "$FOLDER")")" 200
MOVED=$(py 'import json,sys; print(json.load(open(sys.argv[1])).get("movedTo") or "")' "$WORK/r.json")
[ -n "$MOVED" ] && check "cartella eliminata definitivamente" "$(req DELETE "/folders/$(enc "$MOVED")")" 200

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
