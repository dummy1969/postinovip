#!/usr/bin/env bash
# Verifica C4b: sincronizzazione CardDAV nei due sensi con il server VERO (account "main" degli user-secrets).
# MODIFICA LA RUBRICA DEL SERVER, ma solo con contatti di prova creati qui (nome «PostinoVip Prova…», indirizzo
# prova-carddav-…@example.invalid), eliminati alla fine (anche se lo script si interrompe). I contatti già presenti
# sul server non vengono modificati: vengono solo copiati nella cartella di cache TEMPORANEA, cancellata alla fine.
# La cache vera dell'app non viene toccata. Credenziali dagli user-secrets: al core per variabile d'ambiente
# (come fa l'app), a curl in un file 0600 temporaneo; mai sulla riga di comando né a schermo.
#
# Uso: tools/verifica-carddav-sync.sh
# Passi: 1 prima sincronizzazione (scoperta, contatti del server copiati), 2 contatto nuovo dall'app -> server,
# 3 modifica dall'app -> server, 4 modifica da «un altro programma» sul server -> computer, 5 eliminazione
# dall'app -> server, 6 contatto creato ed eliminato sul server -> computer.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
API=$ROOT/core/src/PostinoVip.Api
[ -x "$API/bin/Debug/net10.0/PostinoVip.Api" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
HOST=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["Imap"]["Host"])' "$API/appsettings.json")
SECRETS=$(cd "$API" && dotnet user-secrets list 2>/dev/null)
USER_=$(printf '%s\n' "$SECRETS" | sed -n 's/^Imap:Username = //p')
PASS=$(printf '%s\n' "$SECRETS" | sed -n 's/^Imap:Password = //p')
unset SECRETS
[ -n "$USER_" ] && [ -n "$PASS" ] || { echo "User-secrets Imap:Username/Imap:Password non trovati"; exit 1; }

echo "Account $USER_ su $HOST."
echo "Questa prova MODIFICA LA RUBRICA DEL SERVER: crea, cambia ed elimina due contatti di prova."
echo "I contatti già presenti non vengono toccati. Alla fine i contatti di prova sono eliminati."
read -r -p "Continuare? [s/N] " ok
[ "$ok" = s ] || [ "$ok" = S ] || { echo "Annullato."; exit 0; }

WORK=$(mktemp -d -t postinovip-carddav-sync-XXXX)
umask 077
printf 'machine %s login %s password %s\n' "$HOST" "$USER_" "$PASS" > "$WORK/netrc"
unset PASS # il core la legge dagli user-secrets, come le altre prove
PID=
HREFS=()
cleanup() {
  [ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }
  for h in "${HREFS[@]}"; do
    c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 --netrc-file "$WORK/netrc" --anyauth -X DELETE "https://$HOST$h")
    [ "$c" = 404 ] || echo "   pulizia: DELETE $h -> $c"
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$API" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false Cache__Download__Enabled=false \
  Rules__Enabled=false Outbox__Enabled=false Cache__Directory="$WORK/cache" Api__Port=5099 CardDav__Enabled=true \
  ./bin/Debug/net10.0/PostinoVip.Api > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5099/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
B=http://127.0.0.1:5099/accounts/main
J() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }
code() { curl -s -o /dev/null -w "%{http_code}" -H "$H" "$@"; }
st() { curl -s -H "$H" "$B/contacts/sync"; }
STATE=$WORK/cache/accounts/main/carddav.json
# srv METODO href [opzioni curl...] -> codice HTTP, corpo in $WORK/srv.out
srv() { local m=$1 h=$2; shift 2
  curl -s --max-time 20 --netrc-file "$WORK/netrc" --anyauth -X "$m" -o "$WORK/srv.out" -D "$WORK/srv.hdr" -w '%{http_code}' "$@" "https://$HOST$h"; }
etag() { sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$WORK/srv.hdr" | tr -d '\r'; }
hrefOf() { python3 -I -c 'import json,sys; s=json.load(open(sys.argv[1])); print(next((e["href"] for e in s["entries"] if e.get("contactId")==sys.argv[2]), ""))' "$STATE" "$1"; }
local_notes() { curl -s -H "$H" "$B/contacts" | J "print(next((c.get('notes') or '(vuote)' for c in d['items'] if '$1' in [e['address'] for e in c['emails']]), '(assente)'))"; }

# giro: aspetta che il core sia fermo, chiede una sincronizzazione e ne aspetta la fine
giro() {
  local quiet=0
  for i in $(seq 150); do
    [ "$(st | J 'print(d["state"])')" = syncing ] && quiet=0 || quiet=$((quiet+1))
    [ $quiet -ge 15 ] && break; sleep 0.2
  done
  local before; before=$(st | J 'print(d.get("lastSync") or "")')
  code -X POST "$B/contacts/sync" > /dev/null
  for i in $(seq 150); do
    local s; s=$(st)
    local now; now=$(printf '%s' "$s" | J 'print(d.get("lastSync") or "")')
    [ -n "$now" ] && [ "$now" != "$before" ] && return 0
    case $(printf '%s' "$s" | J 'print(d["state"])') in
      error|offline) echo "   stato: $(printf '%s' "$s" | J 'print(d["state"], "-", d.get("error"))')"; return 1;;
    esac
    sleep 0.2
  done
  echo "   (nessuna sincronizzazione in 30 s)"; return 1
}

TAG=$(openssl rand -hex 4)
MAIL1=prova-carddav-$TAG@example.invalid
MAIL2=prova-carddav-$TAG-srv@example.invalid

echo "1. Prima sincronizzazione (scoperta da https://$HOST/.well-known/carddav):"
for i in $(seq 150); do s=$(st | J 'print(d["state"])'); [ "$s" = waiting ] || [ "$s" = syncing ] || break; sleep 0.2; done
st | J 'print("   stato %s, rubrica «%s», conferma richiesta: %s%s" % (d["state"], d.get("addressBook"), "sì" if d["needsConfirmation"] else "no", (" - " + d["error"]) if d.get("error") else ""))'
[ "$(st | J 'print(d["state"])')" = ok ] || { echo "   Sincronizzazione non riuscita: log del core in fondo."; tail -20 "$WORK/core.log"; exit 1; }
echo "   rubrica: $(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["book"])' "$STATE")"
echo "   contatti del server copiati qui: $(curl -s -H "$H" "$B/contacts" | J 'print(len(d["items"]))')   (atteso: quanti ne ha la rubrica sul server, conferma: no)"

echo "2. Contatto nuovo dall'app:"
ID=$(curl -s -H "$H" -H "Content-Type: application/json" -X POST "$B/contacts" \
  -d "{\"givenName\":\"PostinoVip\",\"familyName\":\"Prova $TAG\",\"emails\":[{\"address\":\"$MAIL1\"}],\"notes\":\"creato dall'app\"}" | J 'print(d["id"])')
giro
H1=$(hrefOf "$ID"); [ -n "$H1" ] && HREFS+=("$H1")
echo "   sul server: $H1 -> GET $(srv GET "$H1")   (atteso 200)"
grep -q "$MAIL1" "$WORK/srv.out" && echo "   contiene l'indirizzo: sì   (atteso sì)" || echo "   contiene l'indirizzo: NO"

echo "3. Modifica dall'app:"
curl -s -o /dev/null -H "$H" -H "Content-Type: application/json" -X PUT "$B/contacts/$ID" \
  -d "{\"givenName\":\"PostinoVip\",\"familyName\":\"Prova $TAG\",\"emails\":[{\"address\":\"$MAIL1\"}],\"notes\":\"cambiato dall'app\"}"
giro
srv GET "$H1" > /dev/null
grep -q "cambiato dall'app" "$WORK/srv.out" && echo "   nota sul server: cambiata   (atteso cambiata)" || echo "   nota sul server: NON cambiata"

echo "4. Modifica da «un altro programma» sul server:"
srv GET "$H1" > /dev/null
E=$(etag)
python3 -I -c '
import sys, datetime
text = open(sys.argv[1], encoding="utf-8").read().replace("\r\n", "\n")
lines = [l for l in text.split("\n") if not l.upper().startswith(("NOTE", "REV"))]
rev = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
i = max(k for k, l in enumerate(lines) if l.upper().startswith("END:VCARD"))
lines[i:i] = ["NOTE:cambiato sul server", "REV:" + rev]
open(sys.argv[2], "w", encoding="utf-8", newline="").write("\r\n".join(l for l in lines if l) + "\r\n")' "$WORK/srv.out" "$WORK/mod.vcf"
echo "   PUT con If-Match: $(srv PUT "$H1" -H "If-Match: $E" -H 'Content-Type: text/vcard; charset=utf-8' --data-binary @"$WORK/mod.vcf")   (atteso 204 o 200)"
giro
echo "   nota sul computer: $(local_notes "$MAIL1")   (atteso cambiato sul server)"

echo "5. Eliminazione dall'app:"
echo "   DELETE nell'app: $(code -X DELETE "$B/contacts/$ID")   (atteso 204)"
giro
echo "   sul server: GET $(srv GET "$H1")   (atteso 404)"

echo "6. Contatto creato ed eliminato sul server:"
H2=$(python3 -I -c 'import json,sys,urllib.parse; print(urllib.parse.urlparse(json.load(open(sys.argv[1]))["book"]).path)' "$STATE")postinovip-prova-$TAG.vcf
HREFS+=("$H2")
printf 'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:postinovip-prova-%s\r\nFN:PostinoVip Prova server %s\r\nN:Prova server %s;PostinoVip;;;\r\nEMAIL;TYPE=INTERNET:%s\r\nEND:VCARD\r\n' \
  "$TAG" "$TAG" "$TAG" "$MAIL2" > "$WORK/new.vcf"
echo "   PUT nuovo: $(srv PUT "$H2" -H 'If-None-Match: *' -H 'Content-Type: text/vcard; charset=utf-8' --data-binary @"$WORK/new.vcf")   (atteso 201)"
echo "   Invia/ricevi: $(code -X POST "$B/receive")   (atteso 202)"
giro
echo "   sul computer: $(local_notes "$MAIL2" | sed 's/(vuote)/presente/')   (atteso presente)"
echo "   DELETE sul server: $(srv DELETE "$H2")   (atteso 204 o 200)"
giro
echo "   sul computer: $(local_notes "$MAIL2" | sed 's/(vuote)/presente/')   (atteso assente)"

echo "7. Riepilogo dal log del core (solo numeri e id):"
grep -E 'CardDAV' "$WORK/core.log" | sed 's/^ */   /' | tail -12
echo "Fine. Contatti di prova eliminati; la cartella temporanea viene cancellata."
