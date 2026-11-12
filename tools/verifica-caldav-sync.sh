#!/usr/bin/env bash
# Verifica K2a: sincronizzazione CalDAV nei due sensi con il server VERO (account "main" degli user-secrets).
# MODIFICA IL CALENDARIO DEL SERVER, ma solo con appuntamenti di prova creati qui (oggetto «PostinoVip prova …»,
# UID postinovip-prova-…), eliminati alla fine (anche se lo script si interrompe). Gli appuntamenti già presenti sul server
# non vengono modificati: vengono solo copiati nella cartella di cache TEMPORANEA, cancellata alla fine. La cache vera
# dell'app non viene toccata. Credenziali dagli user-secrets: il core le legge da lì, a curl vanno in un file 0600
# temporaneo; mai sulla riga di comando né a schermo. A schermo solo numeri e gli oggetti degli appuntamenti di prova.
#
# Uso: tools/verifica-caldav-sync.sh
# Passi: 1 un appuntamento di prova «sul computer» prima di attivare CalDAV, prima sincronizzazione (scoperta, calendari,
# appuntamenti del server copiati, conferma richiesta); 2 conferma -> caricato sul server; 3 appuntamento creato da «un
# altro programma» sul server -> computer (Invia/ricevi); 4 modificato sul server -> computer; 5 eliminato sul server
# -> tolto dal computer. (Modifica ed eliminazione dall'app arrivano con il K2b, che ha gli endpoint degli appuntamenti.)
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
echo "Questa prova MODIFICA IL CALENDARIO DEL SERVER: crea, cambia ed elimina due appuntamenti di prova."
echo "Gli appuntamenti già presenti non vengono toccati. Alla fine quelli di prova sono eliminati."
read -r -p "Continuare? [s/N] " ok
[ "$ok" = s ] || [ "$ok" = S ] || { echo "Annullato."; exit 0; }

WORK=$(mktemp -d -t postinovip-caldav-sync-XXXX)
umask 077
printf 'machine %s login %s password %s\n' "$HOST" "$USER_" "$PASS" > "$WORK/netrc"
unset PASS
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

TAG=$(openssl rand -hex 4)
UID1=postinovip-prova-$TAG-pc
UID2=postinovip-prova-$TAG-srv
ics() { # ics UID OGGETTO -> appuntamento di un'ora domani alle 10 (Europe/Rome), LAST-MODIFIED adesso
  python3 -I -c '
import sys, datetime
uid, summary = sys.argv[1], sys.argv[2]
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
d = (datetime.date.today() + datetime.timedelta(days=1)).strftime("%Y%m%d")
print("\r\n".join(["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//PostinoVip//verifica//IT", "BEGIN:VEVENT", "UID:" + uid,
  "DTSTAMP:" + now, "LAST-MODIFIED:" + now, "DTSTART;TZID=Europe/Rome:" + d + "T100000", "DTEND;TZID=Europe/Rome:" + d + "T110000",
  "SUMMARY:" + summary, "END:VEVENT", "END:VCALENDAR", ""]), end="")' "$1" "$2"
}

# 1a. Un appuntamento «sul computer» prima di attivare CalDAV: il calendario predefinito con un file .ics.
CAL=$WORK/cache/accounts/main/calendars
CALID=0123456789abcdef
ITEM=00000000000000aa
mkdir -p "$CAL/$CALID/items"
printf '[{"id":"%s","name":"Calendario","href":null}]' "$CALID" > "$CAL/calendars.json"
ics "$UID1" "PostinoVip prova $TAG dal computer" > "$CAL/$CALID/items/$ITEM.ics"

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$API" && exec env ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false Cache__Download__Enabled=false \
  Rules__Enabled=false Outbox__Enabled=false Cache__Directory="$WORK/cache" Api__Port=5099 CalDav__Enabled=true \
  ./bin/Debug/net10.0/PostinoVip.Api > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5099/version && break; sleep 0.2; done

H="Authorization: Bearer $POSTINOVIP_TOKEN"
B=http://127.0.0.1:5099/accounts/main
J() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }
code() { curl -s -o /dev/null -w "%{http_code}" -H "$H" "$@"; }
st() { curl -s -H "$H" "$B/calendars/sync"; }
srv() { local m=$1 h=$2; shift 2
  curl -s --max-time 20 --netrc-file "$WORK/netrc" --anyauth -X "$m" -o "$WORK/srv.out" -D "$WORK/srv.hdr" -w '%{http_code}' "$@" "https://$HOST$h"; }
etag() { sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$WORK/srv.hdr" | tr -d '\r'; }
STATE=$CAL/$CALID/caldav.json
hrefOf() { python3 -I -c 'import json,sys; s=json.load(open(sys.argv[1])); print(next((e["href"] for e in s["entries"] if e.get("contactId")==sys.argv[2]), ""))' "$STATE" "$1"; }
bookPath() { python3 -I -c 'import json,sys,urllib.parse; print(urllib.parse.urlparse(json.load(open(sys.argv[1]))["book"]).path)' "$STATE"; }
count() { curl -s -H "$H" "$B/calendars" | J 'print(d["items"][0]["count"])'; }
summaries() { grep -h '^SUMMARY:PostinoVip prova' "$CAL/$CALID/items/"*.ics 2>/dev/null | sed 's/^SUMMARY:/      /' | tr -d '\r'; }

giro() {
  local quiet=0
  for i in $(seq 150); do
    [ "$(st | J 'print(d["state"])')" = syncing ] && quiet=0 || quiet=$((quiet+1))
    [ $quiet -ge 15 ] && break; sleep 0.2
  done
  local before; before=$(st | J 'print(d.get("lastSync") or "")')
  code -X POST "$B/calendars/sync" > /dev/null
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

echo "1. Prima sincronizzazione (scoperta da https://$HOST/.well-known/caldav):"
for i in $(seq 150); do s=$(st | J 'print(d["state"])'); [ "$s" = waiting ] || [ "$s" = syncing ] || break; sleep 0.2; done
st | J 'print("   stato %s, %s, conferma richiesta: %s (in attesa: %d)%s" % (d["state"], d.get("addressBook"), "sì" if d["needsConfirmation"] else "no", d["pendingUpload"], (" - " + d["error"]) if d.get("error") else ""))'
[ "$(st | J 'print(d["state"])')" = ok ] || { echo "   Sincronizzazione non riuscita: log del core in fondo."; tail -20 "$WORK/core.log"; exit 1; }
curl -s -H "$H" "$B/calendars" | J '
for c in d["items"]: print("   calendario «%s»: %d appuntamenti, collegato al server: %s" % (c["name"], c["count"], "sì" if c["synced"] else "no"))'
echo "   (atteso: «Calendario» collegato, con gli appuntamenti del server più 1 di prova; conferma richiesta: sì, in attesa: 1)"
BOOK=$(bookPath)

echo "2. Conferma: l'appuntamento di prova del computer va sul server"
echo "   POST conferma: $(code -X POST "$B/calendars/sync/confirm")   (atteso 202)"
giro
H1=$(hrefOf "$ITEM"); [ -n "$H1" ] && HREFS+=("$H1")
echo "   sul server: ${H1:-(nessuno)} -> GET $(srv GET "${H1:-/x}")   (atteso 200)"
grep -q "$UID1" "$WORK/srv.out" && echo "   contiene l'UID: sì   (atteso sì)" || echo "   contiene l'UID: NO"
st | J 'print("   conferma richiesta: %s   (atteso no)" % ("sì" if d["needsConfirmation"] else "no"))'

echo "3. Appuntamento creato da «un altro programma» sul server"
H2=${BOOK}$UID2.ics
HREFS+=("$H2")
ics "$UID2" "PostinoVip prova $TAG dal server" > "$WORK/new.ics"
BEFORE=$(count)
echo "   PUT nuovo: $(srv PUT "$H2" -H 'If-None-Match: *' -H 'Content-Type: text/calendar; charset=utf-8' --data-binary @"$WORK/new.ics")   (atteso 201)"
echo "   Invia/ricevi: $(code -X POST "$B/receive")   (atteso 202)"
giro
echo "   appuntamenti nel calendario: da $BEFORE a $(count)   (atteso uno in più)"
summaries

echo "4. Modificato sul server"
srv GET "$H2" > /dev/null
E=$(etag)
ics "$UID2" "PostinoVip prova $TAG cambiato sul server" > "$WORK/mod.ics"
echo "   PUT con If-Match: $(srv PUT "$H2" -H "If-Match: $E" -H 'Content-Type: text/calendar; charset=utf-8' --data-binary @"$WORK/mod.ics")   (atteso 204 o 200)"
giro
summaries | grep -q "cambiato sul server" && echo "   sul computer: cambiato   (atteso cambiato)" || echo "   sul computer: NON cambiato"

echo "5. Eliminato sul server"
BEFORE=$(count)
echo "   DELETE: $(srv DELETE "$H2")   (atteso 204 o 200)"
giro
echo "   appuntamenti nel calendario: da $BEFORE a $(count)   (atteso uno in meno)"

echo "6. Riepilogo dal log del core (solo numeri e id):"
grep -E 'CalDAV' "$WORK/core.log" | sed 's/^ */   /' | tail -12
echo "Fine. Gli appuntamenti di prova vengono eliminati dal server; la cartella temporanea viene cancellata."
