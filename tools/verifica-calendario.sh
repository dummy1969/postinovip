#!/usr/bin/env bash
# Verifica K2b: appuntamenti creati, modificati ed eliminati dall'API del core, con la sincronizzazione CalDAV verso il
# server VERO (account "main" degli user-secrets). MODIFICA IL CALENDARIO DEL SERVER, ma solo con appuntamenti di prova
# (oggetto «PostinoVip prova …») creati qui ed eliminati alla fine (anche se lo script si interrompe). Gli appuntamenti già
# presenti vengono solo copiati nella cartella di cache TEMPORANEA (cancellata alla fine) e contati, mai modificati.
# Credenziali dagli user-secrets: il core le legge da lì, a curl vanno in un file 0600 temporaneo; mai a schermo.
#
# Uso: tools/verifica-calendario.sh
# Passi: 1 prima sincronizzazione; 2 serie settimanale (3 volte, ore 9 di Roma, promemoria 15 minuti) creata dall'API ->
# sul server con RRULE, VALARM e VTIMEZONE; 3 occorrenze del periodo; 4 modifica dell'oggetto (ricorrenza invariata) ->
# sul server con SEQUENCE aumentata; 5 come la conserva il server (proprietà dopo il giro, senza contenuti); 6 giornata
# intera; 7 eliminazione dall'API -> tolti dal server.
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

WORK=$(mktemp -d -t postinovip-calendario-XXXX)
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
post() { curl -s -H "$H" -H "Content-Type: application/json" -X "$1" "$2" -d "$3"; }
st() { curl -s -H "$H" "$B/calendars/sync"; }
srv() { local m=$1 h=$2; shift 2
  curl -s --max-time 20 --netrc-file "$WORK/netrc" --anyauth -X "$m" -o "$WORK/srv.out" -w '%{http_code}' "$@" "https://$HOST$h"; }
props() { tr -d '\r' < "$WORK/srv.out" | python3 -I -c '
import sys
names = []
for l in sys.stdin.read().replace("\n ", "").split("\n"):
    if not l or l[0] in " \t": continue
    n = l.split(":", 1)[0].split(";", 1)[0]
    if n not in names: names.append(n)
print("      " + ", ".join(names))'; }
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

TAG=$(openssl rand -hex 4)
MON=$(python3 -I -c 'import datetime as d; t=d.date.today(); print(t + d.timedelta(days=7 - t.weekday()))')   # lunedì prossimo
FROM=$(python3 -I -c 'import datetime as d; print((d.date.today() - d.timedelta(days=1)).isoformat() + "T00:00:00Z")')
TO=$(python3 -I -c 'import datetime as d; print((d.date.today() + d.timedelta(days=60)).isoformat() + "T00:00:00Z")')

echo "1. Prima sincronizzazione:"
for i in $(seq 150); do s=$(st | J 'print(d["state"])'); [ "$s" = waiting ] || [ "$s" = syncing ] || break; sleep 0.2; done
st | J 'print("   stato %s, %s, conferma richiesta: %s%s" % (d["state"], d.get("addressBook"), "sì" if d["needsConfirmation"] else "no", (" - " + d["error"]) if d.get("error") else ""))'
[ "$(st | J 'print(d["state"])')" = ok ] || { echo "   Sincronizzazione non riuscita: log del core in fondo."; tail -20 "$WORK/core.log"; exit 1; }
CAL=$(curl -s -H "$H" "$B/calendars" | J 'print(d["items"][0]["id"])')
echo "   appuntamenti già presenti (copiati qui, non toccati): $(curl -s -H "$H" "$B/calendars" | J 'print(d["items"][0]["count"])')"
STATE=$WORK/cache/accounts/main/calendars/$CAL/caldav.json
hrefOf() { python3 -I -c 'import json,sys; s=json.load(open(sys.argv[1])); print(next((e["href"] for e in s["entries"] if e.get("contactId")==sys.argv[2]), ""))' "$STATE" "$1"; }

echo "2. Serie settimanale creata dall'API (lunedì $MON alle 9, 3 volte, promemoria 15 minuti):"
R=$(post POST "$B/calendars/$CAL/events" "{\"summary\":\"PostinoVip prova $TAG serie\",\"location\":\"Sala prove\",
  \"start\":\"${MON}T09:00\",\"end\":\"${MON}T10:00\",\"timeZone\":\"Europe/Rome\",\"reminderMinutes\":15,
  \"recurrence\":{\"frequency\":\"weekly\",\"days\":[\"MO\"],\"count\":3}}")
ID1=$(printf '%s' "$R" | J 'print(d["id"])')
giro
H1=$(hrefOf "$ID1"); [ -n "$H1" ] && HREFS+=("$H1")
echo "   sul server: ${H1:-(nessuno)} -> GET $(srv GET "${H1:-/x}")   (atteso 200)"
for k in "BEGIN:VALARM" "BEGIN:VTIMEZONE" "TZID=Europe/Rome"; do
  tr -d '\r' < "$WORK/srv.out" | grep -q "$k" && echo "   contiene $k: sì" || echo "   contiene $k: NO"
done
echo "   come il server ha scritto ricorrenza e promemoria (il core li aveva scritti RRULE:FREQ=WEEKLY;COUNT=3;BYDAY=MO e TRIGGER:-PT15M):"
tr -d '\r' < "$WORK/srv.out" | grep -E '^(RRULE|TRIGGER)' | sed 's/^/      /'

echo "2b. Il core riscarica la versione riscritta dal server e la rilegge:"
E=$(curl -s --max-time 20 --netrc-file "$WORK/netrc" --anyauth -o /dev/null -D - "https://$HOST$H1" | sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' | tr -d '\r')
cp "$WORK/srv.out" "$WORK/same.ics"
echo "   PUT dello stesso testo (come «un altro programma»): $(srv PUT "$H1" -H "If-Match: $E" -H 'Content-Type: text/calendar; charset=utf-8' --data-binary @"$WORK/same.ics")   (atteso 204 o 200)"
giro
curl -s -H "$H" "$B/calendars/$CAL/events/$ID1" | J '
r = d.get("recurrence") or {}
print("   ricorrenza: %s, giorni %s, %s volte; personalizzata: %s; promemoria: %s minuti; inizio %s %s" % (
    r.get("frequency"), r.get("days"), r.get("count"), d.get("customRecurrence"), d.get("reminderMinutes"), d.get("start"), d.get("timeZone")))'
echo "   (atteso: weekly, giorni [MO], 3 volte; personalizzata: None; promemoria: 15 minuti; inizio ${MON}T09:00 Europe/Rome)"

echo "3. Occorrenze nei prossimi 60 giorni (solo quelle di prova):"
curl -s -H "$H" "$B/calendars/events?from=$FROM&to=$TO" | J "
for o in d['items']:
    if o['summary'].startswith('PostinoVip prova $TAG'): print('   ', o['start'], '->', o['end'], '(ricorrente)' if o['recurring'] else '')
print('   in tutto nel periodo:', len(d['items']), 'occorrenze (comprese quelle già presenti)')"
echo "   (attese 3 di prova, lunedì alle 08:00Z con l'ora solare)"

echo "4. Modifica dell'oggetto, ricorrenza invariata:"
post PUT "$B/calendars/$CAL/events/$ID1" "{\"summary\":\"PostinoVip prova $TAG serie cambiata\",\"location\":\"Sala prove\",
  \"start\":\"${MON}T09:00\",\"end\":\"${MON}T10:00\",\"timeZone\":\"Europe/Rome\",\"reminderMinutes\":15,\"keepRecurrence\":true}" > /dev/null
giro
srv GET "$H1" > /dev/null
tr -d '\r' < "$WORK/srv.out" | grep -q "serie cambiata" && echo "   oggetto sul server: cambiato   (atteso cambiato)" || echo "   oggetto sul server: NON cambiato"
echo "   SEQUENCE sul server: $(tr -d '\r' < "$WORK/srv.out" | sed -n 's/^SEQUENCE://p')   (atteso 1)"

echo "5. Proprietà che il server conserva della serie (solo i nomi):"
props

echo "6. Giornata intera (domani):"
TOM=$(python3 -I -c 'import datetime as d; print(d.date.today() + d.timedelta(days=1))')
R=$(post POST "$B/calendars/$CAL/events" "{\"summary\":\"PostinoVip prova $TAG giornata\",\"start\":\"$TOM\",\"end\":\"$TOM\",\"allDay\":true}")
ID2=$(printf '%s' "$R" | J 'print(d["id"])')
giro
H2=$(hrefOf "$ID2"); [ -n "$H2" ] && HREFS+=("$H2")
echo "   sul server: GET $(srv GET "${H2:-/x}")   (atteso 200)"
tr -d '\r' < "$WORK/srv.out" | grep -E '^DT(START|END)' | sed 's/^/      /'
echo "   (atteso DTSTART;VALUE=DATE:<domani> e DTEND;VALUE=DATE:<dopodomani>)"

echo "7. Eliminazione dall'API:"
echo "   DELETE serie: $(code -X DELETE "$B/calendars/$CAL/events/$ID1")   giornata: $(code -X DELETE "$B/calendars/$CAL/events/$ID2")   (attesi 204)"
giro
echo "   sul server: serie GET $(srv GET "${H1:-/x}"), giornata GET $(srv GET "${H2:-/x}")   (attesi 404)"

echo "8. Riepilogo dal log del core (solo numeri e id):"
grep -E 'CalDAV' "$WORK/core.log" | sed 's/^ */   /' | tail -10
echo "Fine. La cartella temporanea viene cancellata (e ogni prova rimasta sul server eliminata)."
