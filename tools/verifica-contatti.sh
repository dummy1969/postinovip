#!/usr/bin/env bash
# Verifica C1 (core): rubrica per account, importazione/esportazione, indirizzi recenti e suggerimenti.
# Lavora su una cartella di cache TEMPORANEA (copia del database di "main", per gli indirizzi della Posta
# inviata), cancellata alla fine. La cache vera e la casella non vengono toccate: il server è finto (porta chiusa).
#
# Uso: tools/verifica-contatti.sh [file.csv|file.vcf]
#   con un file (es. un'esportazione di Outlook o di Google Contatti) lo importa nella rubrica di prova
#   e mostra come sono state lette le prime righe: serve a provare le intestazioni del CSV in italiano.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
SRC=$HOME/.local/share/postinovip-dev/accounts/main/index.db
USERFILE=${1:-}
[ -f "$SRC" ] || { echo "Cache di sviluppo non trovata: $SRC"; exit 1; }
[ -x "$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
[ -z "$USERFILE" ] || [ -f "$USERFILE" ] || { echo "File non trovato: $USERFILE"; exit 1; }

WORK=$(mktemp -d -t postinovip-contatti-XXXX)
PID=
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/accounts/main"
python3 -I -c "import sqlite3,sys; s=sqlite3.connect(f'file:{sys.argv[1]}?mode=ro',uri=True); d=sqlite3.connect(sys.argv[2]); s.backup(d); d.close()" "$SRC" "$WORK/accounts/main/index.db"

PORT=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$ROOT/core/src/PostinoVip.Api" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false \
  Cache__Download__Enabled=false Rules__Enabled=false Outbox__Enabled=false Cache__Directory="$WORK" Api__Port=5098 \
  Imap__Host=127.0.0.1 Imap__Port=$PORT Smtp__Host=127.0.0.1 Smtp__Port=$PORT ./bin/Debug/net10.0/PostinoVip.Api > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5098/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
U=http://127.0.0.1:5098
B=$U/accounts/main
J() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }
code() { curl -s -o /dev/null -w "%{http_code}" -H "$H" "$@"; }
b64() { base64 -w0 "$1"; }
DIR=$WORK/accounts/main/contacts

echo "1. Indirizzi usati di recente, presi dalla Posta inviata della copia locale:"
curl -s -H "$H" "$U/addresses/suggest?q=a&limit=1" > /dev/null
python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
items = sorted(d["items"], key=lambda i: -i["count"])
print("   %d indirizzi; i 3 più usati:" % len(items))
for i in items[:3]:
    print("     %-40s %3d volte, ultima %s" % (i["address"], i["count"], i["lastUsed"][:10]))' "$WORK/accounts/main/recent-addresses.json"

echo "2. Nuovo contatto:"
ID=$(curl -s -H "$H" -H "Content-Type: application/json" -X POST "$B/contacts" -d '{"givenName":"Mario","familyName":"Rossi",
  "company":"Prova Srl","emails":[{"address":"mario.rossi@example.com","label":"work"}],"phones":[{"number":"333 1234567","label":"mobile"}],
  "notes":"Contatto di prova"}' | J 'print(d["id"])')
echo "   id $ID, file $(stat -c '%n %a' "$DIR/$ID.vcf" | sed "s|$WORK/||")   (atteso permessi 600)"
sed 's/^/     | /' "$DIR/$ID.vcf"
echo "   indirizzo non valido: $(code -H "Content-Type: application/json" -X POST "$B/contacts" -d '{"givenName":"X","emails":[{"address":"non valido"}]}')   (atteso 400)"

echo "3. Importazione di un vCard 2.1 come quello di Outlook (accenti in quoted-printable) e di un CSV di Google:"
printf 'BEGIN:VCARD\r\nVERSION:2.1\r\nN;CHARSET=Windows-1252;ENCODING=QUOTED-PRINTABLE:Nicol=F2;Luca\r\nEMAIL;INTERNET:luca@example.org\r\nTEL;CELL:347 1\r\nEND:VCARD\r\n' > "$WORK/prova.vcf"
printf 'First Name,Last Name,E-mail 1 - Label,E-mail 1 - Value\nAnna,Bianchi,* Work,anna@example.org ::: anna.b@example.org\n' > "$WORK/prova.csv"
echo "   vcf: $(curl -s -H "$H" -H "Content-Type: application/json" -X POST "$B/contacts/import" -d "{\"format\":\"vcf\",\"data\":\"$(b64 "$WORK/prova.vcf")\"}")"
echo "   csv: $(curl -s -H "$H" -H "Content-Type: application/json" -X POST "$B/contacts/import" -d "{\"format\":\"csv\",\"data\":\"$(b64 "$WORK/prova.csv")\"}")"
echo "   di nuovo lo stesso vcf: $(curl -s -H "$H" -H "Content-Type: application/json" -X POST "$B/contacts/import" -d "{\"format\":\"vcf\",\"data\":\"$(b64 "$WORK/prova.vcf")\"}")   (atteso imported 0, duplicates 1)"
curl -s -H "$H" "$B/contacts" | J '
for c in d["items"]:
    print("     %-15s %s" % (c["name"], ", ".join(e["address"] for e in c["emails"])))'

echo "4. Esportazione:"
curl -s -H "$H" "$B/contacts/export?format=vcf" -o "$WORK/tutti.vcf"
curl -s -H "$H" "$B/contacts/export?format=csv" -o "$WORK/tutti.csv"
echo "   vcf: $(grep -c BEGIN:VCARD "$WORK/tutti.vcf") contatti; csv: $(($(python3 -I -c 'import csv,sys; print(sum(1 for _ in csv.reader(open(sys.argv[1], encoding="utf-8-sig"))))' "$WORK/tutti.csv") - 1)) righe; intestazione: $(head -1 "$WORK/tutti.csv" | cut -c4-60)…"

echo "5. Suggerimenti (contatti e indirizzi recenti):"
for q in mario nicolo "$(python3 -I -c 'import json,sys; i=json.load(open(sys.argv[1]))["items"]; print(max(i,key=lambda x:x["count"])["address"][:3] if i else "zz")' "$WORK/accounts/main/recent-addresses.json")"; do
  echo "   «$q»: $(curl -s -H "$H" "$U/addresses/suggest?q=$q&limit=3" | J 'print("; ".join("%s <%s> [%s]" % (i["name"] or "", i["address"], "contatto" if i["source"]=="contact" else "recente") for i in d["items"]) or "(nessuno)")')"
done
FIRST=$(curl -s -H "$H" "$U/addresses/suggest?q=a&limit=50" | J 'r=[i["address"] for i in d["items"] if i["source"]=="recent"]; print(r[0] if r else "")')
if [ -n "$FIRST" ]; then
  echo "6. ✕ su un indirizzo recente ($FIRST): $(code -X DELETE "$U/addresses/recent?address=$FIRST")   (atteso 204)"
  echo "   ancora suggerito? $(curl -s -H "$H" "$U/addresses/suggest?q=$FIRST&limit=50" | J "print('sì' if any(i['address'].lower()=='${FIRST,,}' for i in d['items']) else 'no')")   (atteso no)"
fi

echo "7. Ricostruisci cache di main: $(code -X POST "$B/cache/rebuild")   (atteso 202)"
sleep 0.5
echo "   contatti dopo la ricostruzione: $(curl -s -H "$H" "$B/contacts" | J 'print(len(d["items"]))')   (atteso 3: restano)"

if [ -n "$USERFILE" ]; then
  EXT=$(echo "${USERFILE##*.}" | tr 'A-Z' 'a-z')
  echo "8. Il tuo file ($USERFILE, formato $EXT), nella stessa rubrica di prova (temporanea):"
  echo "   $(curl -s -H "$H" -H "Content-Type: application/json" -X POST "$B/contacts/import" -d "{\"format\":\"$EXT\",\"data\":\"$(b64 "$USERFILE")\"}")"
  curl -s -H "$H" "$B/contacts" | J '
items = [c for c in d["items"] if c["name"] not in ("Mario Rossi", "Luca Nicolò", "Anna Bianchi")]
print("   %d contatti letti; i primi 5:" % len(items))
for c in items[:5]:
    print("     nome=%r cognome=%r società=%r" % (c["givenName"], c["familyName"], c["company"]))
    print("       email=%s telefoni=%s note=%s" % ([e["address"] for e in c["emails"]], [(p["number"], p["label"]) for p in c["phones"]], "sì" if c["notes"] else "no"))'
fi
