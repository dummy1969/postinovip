#!/usr/bin/env bash
# Verifica C1 (core): Ignora conversazione e Pulisci, account "main" (user-secrets).
# MODIFICA LA CASELLA (nessuna mail inviata):
#   1. crea la cartella "PostinoVip-conversazioni" e ci aggiunge (IMAP APPEND, nessun invio) quattro mail di prova da
#      un mittente inventato (@example.invalid), già lette: due conversazioni (A con la risposta B che la cita per
#      intero, X con la risposta Y che non la cita);
#   2. «Pulisci cartella» sulla cartella di prova: solo A deve andare in Posta eliminata;
#   3. «Ignora conversazione» su X: X e Y in Posta eliminata; poi aggiunge in Posta in arrivo una risposta Z a Y, che
#      il filtro deve spostare da sola in Posta eliminata (serve l'avviso IDLE: fino a 60 secondi);
#   4. «Interrompi Ignora conversazione» da Posta eliminata: X, Y e Z tornano in Posta in arrivo;
#   5. pulisce: elimina definitivamente le mail di prova e la cartella di prova.
# Le regole girano con una copia locale temporanea (nessuna regola, risposta automatica o filtro della posta
# indesiderata attivo: le tue scelte non cambiano). Nessun'altra mail viene toccata. Credenziali da un file privato
# (0600, cancellato alla fine), mai sulla riga di comando né sullo schermo; certificato verificato. Chiede conferma
# prima di cominciare. Chiudere prima l'app. Mostra solo numeri, sì/no e nomi delle cartelle.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
[ -x "$CORE" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }

WORK=$(mktemp -d -t postinovip-conversazioni-XXXX)
chmod 700 "$WORK"
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT

(umask 077; dotnet user-secrets list --project "$ROOT/core/src/PostinoVip.Api" > "$WORK/secrets" 2>/dev/null)
grep -q '^Imap:Password' "$WORK/secrets" || { echo "User-secrets di main mancanti (Imap:Username / Imap:Password)"; exit 1; }

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Cache__Directory="$WORK/cache" \
  Cache__Download__Enabled=false Outbox__Enabled=false Api__Port=5103 "$CORE" > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5103/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5103
OK=0; KO=0
check() { # check "descrizione" ottenuto atteso
  if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  OK     %s: %s\n' "$1" "$2"
  else KO=$((KO+1)); printf '  ERRORE %s: %s (atteso %s)\n' "$1" "$2" "$3"; fi
}
py() { python3 -I -c "$1" "${@:2}"; }
req() { curl -s -o "$WORK/r.json" -w "%{http_code}" -X "$1" -H "$H" -H "Content-Type: application/json" ${3:+--data "$3"} "$U$2"; }
enc() { py 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
field() { py 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2]); print("null" if v is None else (len(v) if isinstance(v, list) else v))' "$WORK/r.json" "$1"; }
role() { curl -s -H "$H" "$U/folders" | py 'import json,sys; print(next((f["fullName"] for f in json.load(sys.stdin) if f.get("specialUse")==sys.argv[1]), ""))' "$1"; }
# UID della mail con l'oggetto dato nella cartella ("" se non c'è).
uid() { curl -s -H "$H" "$U/folders/$(enc "$1")/messages?limit=100" | py 'import json,sys; m=next((m for m in json.load(sys.stdin).get("items", []) if m["subject"]==sys.argv[1]), None); print("" if m is None else m["uid"])' "$2"; }
# Lettere delle mail di prova presenti nella cartella, in ordine (es. "BXY").
letters() { curl -s -H "$H" "$U/folders/$(enc "$1")/messages?limit=100" | py 'import json,sys; p=sys.argv[1]; print("".join(sorted(m["subject"][len(p):] for m in json.load(sys.stdin).get("items", []) if m["subject"].startswith(p))))' "$PREFIX"; }

# IMAP diretto: "<cartella> <codice> <lettera> <genitore o -> <testo> <mittente> <prefisso>" (mail già letta, nessun invio).
imap() { python3 -I - "$WORK/secrets" "$@" <<'EOF'
import imaplib, ssl, sys, email.utils
secrets = dict(l.split(" = ", 1) for l in open(sys.argv[1]).read().splitlines() if " = " in l)
host, port = secrets["Imap:Host"], int(secrets.get("Imap:Port", "993"))
context = ssl.create_default_context()
imap = imaplib.IMAP4_SSL(host, port, ssl_context=context) if port == 993 else imaplib.IMAP4(host, port)
if port != 993:
    imap.starttls(ssl_context=context)
imap.login(secrets["Imap:Username"], secrets["Imap:Password"])
folder, code, letter, parent, text, sender, prefix = sys.argv[2:9]
reply = "" if parent == "-" else f"In-Reply-To: <{code}-{parent}@example.invalid>\r\nReferences: <{code}-{parent}@example.invalid>\r\n"
raw = (f"From: Prova PostinoVip <{sender}>\r\nTo: {secrets['Imap:Username']}\r\nSubject: {prefix}{letter}\r\n"
       f"Date: {email.utils.formatdate(localtime=True)}\r\nMessage-ID: <{code}-{letter}@example.invalid>\r\n{reply}\r\n"
       f"{text}\r\n")
typ, _ = imap.append(folder, "(\\Seen)", None, raw.encode())
print(typ)
imap.logout()
EOF
}
add() { imap "$1" "$CODE" "$2" "$3" "$4" "$SENDER" "$PREFIX"; }

ADDRESS=$(curl -s -H "$H" "$U/accounts" | py 'import json,sys; a=json.load(sys.stdin); print(a[0]["address"] if a else "")')
[ -n "$ADDRESS" ] || { echo "Core non avviato o account main non configurato:"; tail -5 "$WORK/core.log"; exit 1; }
TRASH=$(role trash)
[ -n "$TRASH" ] || { echo "Il server non dichiara Posta eliminata (SPECIAL-USE)."; exit 1; }
CODE=$(openssl rand -hex 4)
FOLDER="PostinoVip-conversazioni"
PREFIX="PostinoVip prova conversazioni $CODE "
SENDER="prova-$CODE@example.invalid"

echo "Account: $ADDRESS"
echo "La prova CREA la cartella \"$FOLDER\", ci AGGIUNGE (APPEND, nessun invio) quattro mail di prova da un mittente"
echo "inventato, ne SPOSTA in Posta eliminata con Pulisci e Ignora, AGGIUNGE una risposta in Posta in arrivo (spostata"
echo "dal filtro), riporta la conversazione in Posta in arrivo e alla fine ELIMINA DEFINITIVAMENTE le mail di prova e la cartella."
read -r -p "Procedere sul server vero? [s/N] " ANSWER
[ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ] || { echo "Annullato: nessuna modifica."; exit 0; }

echo "1. Mail di prova"
check "cartella di prova creata" "$(req POST /folders "{\"name\":\"$FOLDER\"}")" 201
check "A aggiunta" "$(add "$FOLDER" A - "Ciao, ci vediamo domani alle 10 per il preventivo?")" OK
check "B (cita A per intero) aggiunta" "$(add "$FOLDER" B A $'Va bene, a domani.\r\n\r\n> Ciao, ci vediamo domani alle 10\r\n> per il preventivo?')" OK
check "X aggiunta" "$(add "$FOLDER" X - "Mi mandi il listino aggiornato?")" OK
check "Y (non cita X) aggiunta" "$(add "$FOLDER" Y X "Te lo mando lunedì.")" OK
check "mail nella cartella di prova" "$(letters "$FOLDER")" ABXY

echo "2. Pulisci cartella"
check "Pulisci cartella" "$(req POST "/folders/$(enc "$FOLDER")/clean-up")" 200
check "mail esaminate" "$(field checked)" 4
check "mail spostate" "$(field uids)" 1
check "destinazione" "$(field movedTo)" "$TRASH"
check "restano nella cartella" "$(letters "$FOLDER")" BXY
check "in Posta eliminata" "$(letters "$TRASH")" A
check "Pulisci in Posta eliminata rifiutato" "$(req POST "/folders/$(enc "$TRASH")/clean-up")" 409

echo "3. Ignora conversazione"
X=$(uid "$FOLDER" "${PREFIX}X")
check "conversazione non ignorata" "$(req GET "/messages/$(enc "$FOLDER")/$X/ignored"; echo -n " "; field ignored)" "200 False"
check "Ignora su X" "$(req POST "/messages/$(enc "$FOLDER")/ignore" "{\"uids\":[$X]}")" 200
check "mail spostate" "$(field uids)" 2
check "restano nella cartella" "$(letters "$FOLDER")" B
check "in Posta eliminata" "$(letters "$TRASH")" AXY
T=$(uid "$TRASH" "${PREFIX}X")
check "conversazione ignorata" "$(req GET "/messages/$(enc "$TRASH")/$T/ignored"; echo -n " "; field ignored)" "200 True"
sleep 5 # il filtro parte 3 secondi dopo l'avvio e fissa il punto di partenza
check "risposta Z aggiunta in Posta in arrivo" "$(add INBOX Z Y "Grazie, aspetto.")" OK
WHERE=""
for i in $(seq 60); do
  [ -n "$(uid "$TRASH" "${PREFIX}Z")" ] && { WHERE="Posta eliminata"; break; }
  sleep 1
done
check "Z spostata dal filtro in Posta eliminata" "${WHERE:-no}" "Posta eliminata"
check "Z non più in Posta in arrivo" "$(letters INBOX)" ""

echo "4. Interrompi Ignora conversazione"
T=$(uid "$TRASH" "${PREFIX}X")
check "Interrompi Ignora da Posta eliminata" "$(req POST "/messages/$(enc "$TRASH")/stop-ignoring" "{\"uids\":[$T]}")" 200
check "mail riportate" "$(field uids)" 3
check "destinazione" "$(field movedTo)" INBOX
check "in Posta in arrivo" "$(letters INBOX)" XYZ
check "in Posta eliminata resta solo A" "$(letters "$TRASH")" A
grep -E "\[main\] (IGNORA|INTERROMPI|PULISCI)|\[main\] conversazioni ignorate" "$WORK/core.log" | sed 's/^.*\[main\]/         [main]/' | head -6
check "nel log nessun oggetto né indirizzo di prova" "$(grep -c "$CODE" "$WORK/core.log")" 0

echo "5. Pulizia"
for F in "$FOLDER" INBOX "$TRASH"; do
  for L in A B X Y Z; do
    M=$(uid "$F" "$PREFIX$L"); [ -n "$M" ] || continue
    if [ "$F" != "$TRASH" ]; then
      check "$L in Posta eliminata" "$(req DELETE "/messages/$(enc "$F")/$M")" 200
      M=$(uid "$TRASH" "$PREFIX$L"); [ -n "$M" ] || continue
    fi
    check "$L eliminata definitivamente" "$(req DELETE "/messages/$(enc "$TRASH")/$M?permanent=true")" 200
  done
done
check "cartella in Posta eliminata" "$(req DELETE "/folders/$(enc "$FOLDER")")" 200
MOVED=$(py 'import json,sys; print(json.load(open(sys.argv[1])).get("movedTo") or "")' "$WORK/r.json")
[ -n "$MOVED" ] && check "cartella eliminata definitivamente" "$(req DELETE "/folders/$(enc "$MOVED")")" 200
check "nessuna mail di prova rimasta" "$(letters INBOX)$(letters "$TRASH")" ""

echo
echo "Risultato: $OK controlli riusciti, $KO non riusciti."
[ "$KO" -eq 0 ] || { echo "Ultime righe del core:"; tail -20 "$WORK/core.log"; exit 1; }
