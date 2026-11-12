#!/usr/bin/env bash
# Verifica G2: sincronizzazione CalDAV nei due sensi con il calendario VERO di Google, con OAuth2.
# MODIFICA IL CALENDARIO GOOGLE, ma solo con appuntamenti di prova (oggetto «PostinoVip prova <tag> …») creati qui ed
# eliminati alla fine (anche se lo script si interrompe; la pulizia elimina solo ciò che contiene il <tag>). Gli
# appuntamenti già presenti vengono solo copiati nella cartella di cache TEMPORANEA (cancellata alla fine) e contati.
# La cache vera dell'app e il suo account Gmail non vengono toccati. Token solo in file 0600 temporanei, mai a schermo.
#
# Uso: tools/verifica-google-caldav-sync.sh
# Passi: 1 accesso; 2 prima sincronizzazione (calendari, sola lettura); 3 serie settimanale dall'app -> Google; 4 come la
# rilegge il core; 5 modifica dall'app; 6 modifica da «un altro programma» su Google; 7 giornata intera; 8 calendario
# di sola lettura (409); 9 eliminazione dall'app; 10 appuntamento creato ed eliminato su Google; 11 diagnosi RRULE.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
API=$ROOT/core/src/PostinoVip.Api
[ -x "$API/bin/Debug/net10.0/PostinoVip.Api" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
[ -f "$API/oauth-clients.json" ] || { echo "Manca $API/oauth-clients.json (client ID di Google)"; exit 1; }

echo "Questa prova MODIFICA IL CALENDARIO GOOGLE: crea, cambia ed elimina tre appuntamenti di prova."
echo "Gli appuntamenti già presenti non vengono toccati. Alla fine quelli di prova sono eliminati."
read -r -p "Continuare? [s/N] " ok
[ "$ok" = s ] || [ "$ok" = S ] || { echo "Annullato."; exit 0; }

WORK=$(mktemp -d -t postinovip-gcaldav-sync-XXXX)
umask 077
PID=
HREFS=()
TAG=$(openssl rand -hex 4)
GHOST=apidata.googleusercontent.com
srv() { local m=$1 u=$2; shift 2   # srv METODO percorso [opzioni curl...] -> codice HTTP, corpo in srv.out
  case $u in http*) ;; *) u="https://$GHOST$u";; esac
  curl -s --max-time 30 -H @"$WORK/auth.hdr" -X "$m" -o "$WORK/srv.out" -D "$WORK/srv.hdr" -w '%{http_code}' "$@" "$u"; }
cleanup() {
  [ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }
  if [ -f "$WORK/auth.hdr" ]; then
    for h in "${HREFS[@]}"; do
      [ "$(srv GET "$h")" = 200 ] && grep -q "$TAG" "$WORK/srv.out" || continue   # solo ciò che è della prova
      c=$(srv DELETE "$h"); echo "   pulizia: DELETE …/$(basename "$h") -> $c"
    done
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
H="Authorization: Bearer $POSTINOVIP_TOKEN"
J() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }
code() { curl -s -o /dev/null -w "%{http_code}" -H "$H" "$@"; }
post() { curl -s -H "$H" -H "Content-Type: application/json" -X "$1" "$2" -d "$3"; }
core() {
  (cd "$API"
   export ASPNETCORE_ENVIRONMENT=Production Watch__Enabled=false Cache__Download__Enabled=false Rules__Enabled=false \
     Outbox__Enabled=false Pop3__Enabled=false Cache__Directory="$WORK/cache" Api__Port=5099
   if [ -f "$WORK/env" ]; then while IFS='=' read -r k v; do export "$k=$v"; done < "$WORK/env"; fi
   exec ./bin/Debug/net10.0/PostinoVip.Api > "$WORK/core.log" 2>&1) &
  PID=$!
  for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5099/version && break; sleep 0.2; done
}
stop() { kill $PID 2>/dev/null; wait $PID 2>/dev/null; PID=; }

echo "1. Accesso con Google con il permesso del calendario (si apre il browser)"
Imap__Host=imap.example.invalid Smtp__Host=smtp.example.invalid core
START=$(post POST http://127.0.0.1:5099/oauth/start '{"provider":"google","calendar":true}')
ID=$(printf '%s' "$START" | J 'print(d.get("id",""))' 2>/dev/null)
URL=$(printf '%s' "$START" | J 'print(d.get("authorizationUrl",""))' 2>/dev/null)
[ -n "$ID" ] || { echo "   NO: accesso non avviato: $START"; exit 1; }
xdg-open "$URL" >/dev/null 2>&1 || echo "   Apri a mano: $URL"
FLOW=
for i in $(seq 150); do
  FLOW=$(curl -s -H "$H" "http://127.0.0.1:5099/oauth/flows/$ID")
  [ "$(printf '%s' "$FLOW" | J 'print(d.get("status",""))' 2>/dev/null)" = pending ] || break
  sleep 2
done
[ "$(printf '%s' "$FLOW" | J 'print(d.get("status",""))' 2>/dev/null)" = done ] || { echo "   NO: accesso non riuscito"; exit 1; }
printf '%s' "$FLOW" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); open(sys.argv[1],"w").write(d["refreshToken"]); print(d.get("email") or "", "sì" if d.get("calendar") else "NO")' "$WORK/rt" > "$WORK/who"
unset FLOW
read -r EMAIL GRANTED < "$WORK/who"
echo "   accesso riuscito per $EMAIL, permesso del calendario: $GRANTED   (atteso sì)"
[ "$GRANTED" = sì ] || exit 1
stop
python3 -I - "$API/oauth-clients.json" "$WORK/rt" "$WORK/auth.hdr" <<'PY' || { echo "   NO: token di accesso non ottenuto"; exit 1; }
import json, sys, urllib.parse, urllib.request
c = json.load(open(sys.argv[1])); g = (c.get("OAuth") or c)["Google"]
form = {"grant_type": "refresh_token", "refresh_token": open(sys.argv[2]).read(), "client_id": g["ClientId"]}
if g.get("ClientSecret"): form["client_secret"] = g["ClientSecret"]
r = json.load(urllib.request.urlopen("https://oauth2.googleapis.com/token", urllib.parse.urlencode(form).encode(), timeout=20))
open(sys.argv[3], "w").write("Authorization: Bearer " + r["access_token"] + "\n")
PY
python3 -I - "$WORK/env" "$EMAIL" "$WORK/rt" <<'PY'
import sys
email, rt = sys.argv[2], open(sys.argv[3]).read()
v = {"Id": "gm", "Name": "Gmail", "Imap__Host": "imap.gmail.com", "Imap__Port": "993", "Imap__Username": email,
     "Imap__Security": "SslOnConnect", "Smtp__Host": "smtp.gmail.com", "Smtp__Port": "587", "Smtp__Username": email,
     "Smtp__Security": "StartTls", "OAuth__Provider": "google", "OAuth__RefreshToken": rt, "CalDav__Enabled": "true"}
open(sys.argv[1], "w").write("".join(f"Accounts__0__{k}={x}\n" for k, x in v.items()))
PY
core
B=http://127.0.0.1:5099/accounts/gm
st() { curl -s -H "$H" "$B/calendars/sync"; }
lastsync() { st | J 'print(d.get("lastSync") or "")'; }
# aspetta il giro partito da solo dopo una modifica nell'app (lastSync diverso da $1)
waitsync() { for i in $(seq 200); do local n; n=$(lastsync); [ -n "$n" ] && [ "$n" != "$1" ] && [ "$(st | J 'print(d["state"])')" != syncing ] && return 0; sleep 0.2; done; echo "   (nessuna sincronizzazione in 40 s)"; }
giro() { local b; b=$(lastsync); code -X POST "$B/calendars/sync" > /dev/null; waitsync "$b"; }
calstate() { echo "$WORK/cache/accounts/gm/calendars/$CAL/caldav.json"; }
hrefOf() { python3 -I -c 'import json,sys; s=json.load(open(sys.argv[1])); print(next((e["href"] for e in s["entries"] if e.get("contactId")==sys.argv[2]), ""))' "$(calstate)" "$1"; }
lines() { tr -d '\r' < "$WORK/srv.out" | sed -e ':a' -e '$!N;s/\n //;ta' -e 'P;D' | grep -E "$1" | sed 's/^/      /'; }
MON=$(python3 -I -c 'import datetime as d; t=d.date.today(); print(t + d.timedelta(days=7 - t.weekday()))')
TOM=$(python3 -I -c 'import datetime as d; print(d.date.today() + d.timedelta(days=1))')
FROM=$(python3 -I -c 'import datetime as d; print((d.date.today() - d.timedelta(days=1)).isoformat() + "T00:00:00Z")')
TO=$(python3 -I -c 'import datetime as d; print((d.date.today() + d.timedelta(days=60)).isoformat() + "T00:00:00Z")')

echo "2. Prima sincronizzazione:"
for i in $(seq 600); do s=$(st | J 'print(d["state"])'); [ "$s" = waiting ] || [ "$s" = syncing ] || break; sleep 0.2; done
st | J 'print("   stato %s, %s, conferma richiesta: %s%s" % (d["state"], d.get("addressBook"), "sì" if d["needsConfirmation"] else "no", (" - " + d["error"]) if d.get("error") else ""))'
[ "$(st | J 'print(d["state"])')" = ok ] || { echo "   Sincronizzazione non riuscita: log del core in fondo."; tail -20 "$WORK/core.log"; exit 1; }
curl -s -H "$H" "$B/calendars" | J '
for i, c in enumerate(d["items"]): print("   - «%s»%s: %d appuntamenti%s" % (c["name"], " (predefinito)" if i == 0 else "", c["count"], ", SOLA LETTURA" if c.get("readOnly") else ""))'
echo "   (atteso: il principale per primo e scrivibile; le due festività di sola lettura)"
CAL=$(curl -s -H "$H" "$B/calendars" | J 'print(d["items"][0]["id"])')
RO=$(curl -s -H "$H" "$B/calendars" | J 'print(next((c["id"] for c in d["items"] if c.get("readOnly")), ""))')

echo "3. Serie settimanale dall'app (lunedì $MON alle 9 di Roma, 3 volte, promemoria 15 minuti):"
B0=$(lastsync)
ID1=$(post POST "$B/calendars/$CAL/events" "{\"summary\":\"PostinoVip prova $TAG serie\",\"location\":\"Sala prove\",
  \"start\":\"${MON}T09:00\",\"end\":\"${MON}T10:00\",\"timeZone\":\"Europe/Rome\",\"reminderMinutes\":15,
  \"recurrence\":{\"frequency\":\"weekly\",\"days\":[\"MO\"],\"count\":3}}" | J 'print(d["id"])')
waitsync "$B0"
H1=$(hrefOf "$ID1"); [ -n "$H1" ] && HREFS+=("$H1")
echo "   log del core: $(grep -o 'CalDAV: elemento [^ ]* caricato.*' "$WORK/core.log" | tail -1 | sed 's/elemento [^ ]* //')"
echo "   su Google: …/$(basename "${H1:-nessuno}") -> GET $(srv GET "${H1:-/x}")   (atteso 200)"
echo "   come l'ha scritto Google (il core: RRULE:FREQ=WEEKLY;COUNT=3;BYDAY=MO, TRIGGER:-PT15M, VTIMEZONE Europe/Rome):"
lines '^(RRULE|TRIGGER|DTSTART|BEGIN:VTIMEZONE|TZID)'

echo "4. Il core rilegge la versione di Google:"
giro
curl -s -H "$H" "$B/calendars/$CAL/events/$ID1" | J '
r = d.get("recurrence") or {}
print("   ricorrenza: %s, giorni %s, %s volte; personalizzata: %s; promemoria: %s minuti; inizio %s %s" % (
    r.get("frequency"), r.get("days"), r.get("count"), d.get("customRecurrence"), d.get("reminderMinutes"), d.get("start"), d.get("timeZone")))'
echo "   (atteso: weekly, giorni [MO], 3 volte; personalizzata: None; promemoria: 15 minuti; inizio ${MON}T09:00 Europe/Rome)"
curl -s -H "$H" "$B/calendars/events?from=$FROM&to=$TO" | J "
print('   occorrenze di prova nei prossimi 60 giorni:', ', '.join(o['start'] for o in d['items'] if o['summary'].startswith('PostinoVip prova $TAG')), ' (attese 3, lunedì 08:00Z)')"

echo "5. Modifica dall'app (oggetto, ricorrenza invariata):"
B0=$(lastsync)
post PUT "$B/calendars/$CAL/events/$ID1" "{\"summary\":\"PostinoVip prova $TAG serie cambiata\",\"location\":\"Sala prove\",
  \"start\":\"${MON}T09:00\",\"end\":\"${MON}T10:00\",\"timeZone\":\"Europe/Rome\",\"reminderMinutes\":15,\"keepRecurrence\":true}" > /dev/null
waitsync "$B0"
srv GET "$H1" > /dev/null
grep -q "serie cambiata" "$WORK/srv.out" && echo "   oggetto su Google: cambiato   (atteso cambiato)" || echo "   oggetto su Google: NON cambiato"

echo "6. Modifica da «un altro programma» su Google (oggetto):"
E=$(sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$WORK/srv.hdr" | tr -d '\r')
sed "s/serie cambiata/serie cambiata altrove/" "$WORK/srv.out" > "$WORK/mod.ics"
echo "   ETag letto: $([ -n "$E" ] && echo sì || echo NO)   PUT con If-Match: $(srv PUT "$H1" -H "If-Match: $E" -H 'Content-Type: text/calendar; charset=utf-8' --data-binary @"$WORK/mod.ics")   (atteso 204 o 200)"
giro
echo "   oggetto sul computer: $(curl -s -H "$H" "$B/calendars/$CAL/events/$ID1" | J 'print(d.get("summary"))')   (atteso …serie cambiata altrove)"

echo "7. Giornata intera (domani):"
B0=$(lastsync)
ID2=$(post POST "$B/calendars/$CAL/events" "{\"summary\":\"PostinoVip prova $TAG giornata\",\"start\":\"$TOM\",\"end\":\"$TOM\",\"allDay\":true}" | J 'print(d["id"])')
waitsync "$B0"
H2=$(hrefOf "$ID2"); [ -n "$H2" ] && HREFS+=("$H2")
echo "   su Google: GET $(srv GET "${H2:-/x}")   (atteso 200)"
lines '^DT(START|END)'
echo "   (atteso DTSTART;VALUE=DATE:<domani> e DTEND;VALUE=DATE:<dopodomani>)"

echo "8. Calendario di sola lettura:"
if [ -n "$RO" ]; then
  echo "   nuovo appuntamento nelle festività: $(code -H 'Content-Type: application/json' -X POST "$B/calendars/$RO/events" -d "{\"summary\":\"PostinoVip prova $TAG\",\"start\":\"$TOM\",\"end\":\"$TOM\",\"allDay\":true}")   (atteso 409)"
else echo "   nessun calendario di sola lettura trovato"; fi

echo "9. Eliminazione dall'app:"
B0=$(lastsync)
echo "   DELETE serie: $(code -X DELETE "$B/calendars/$CAL/events/$ID1")   giornata: $(code -X DELETE "$B/calendars/$CAL/events/$ID2")   (attesi 204)"
waitsync "$B0"
echo "   su Google: serie GET $(srv GET "${H1:-/x}"), giornata GET $(srv GET "${H2:-/x}")   (attesi 404)"

echo "10. Appuntamento creato ed eliminato su Google (da «un altro programma»):"
BOOK=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["book"])' "$(calstate)")
UID3=postinovip-prova-$TAG-esterno
H3=$(python3 -I -c 'import sys,urllib.parse as u; print(u.urlparse(sys.argv[1]).path)' "$BOOK")$UID3.ics
HREFS+=("$H3")
NOW=$(date -u +%Y%m%dT%H%M%SZ)
printf 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//prova//IT\r\nBEGIN:VEVENT\r\nUID:%s\r\nDTSTAMP:%s\r\nDTSTART;VALUE=DATE:%s\r\nDTEND;VALUE=DATE:%s\r\nSUMMARY:PostinoVip prova %s esterno\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n' \
  "$UID3" "$NOW" "${TOM//-/}" "$(python3 -I -c 'import datetime as d; print((d.date.today() + d.timedelta(days=2)).strftime("%Y%m%d"))')" "$TAG" > "$WORK/new.ics"
echo "   PUT nuovo: $(srv PUT "$H3" -H 'If-None-Match: *' -H 'Content-Type: text/calendar; charset=utf-8' --data-binary @"$WORK/new.ics")   (atteso 201)"
L=$(sed -n 's/^[Ll]ocation: *//p' "$WORK/srv.hdr" | tr -d '\r'); [ -n "$L" ] && { H3=$(python3 -I -c 'import sys,urllib.parse as u; print(u.urlparse(sys.argv[1]).path)' "$L"); HREFS+=("$H3"); echo "   Location: …/$(basename "$H3")"; }
echo "   Invia/ricevi: $(code -X POST "$B/receive")   (atteso 202)"
giro
seen() { curl -s -H "$H" "$B/calendars/events?from=$FROM&to=$TO" | J "print('presente' if any(o['summary'] == 'PostinoVip prova $TAG esterno' for o in d['items']) else 'assente')"; }
echo "   sul computer: $(seen)   (atteso presente)"
echo "   DELETE su Google: $(srv DELETE "$H3")   (atteso 204 o 200)"
giro
echo "   sul computer: $(seen)   (atteso assente)"

echo "11. Diagnosi delle righe RRULE (copia locale del principale, solo numeri):"
python3 -I - "$WORK/cache/accounts/gm/calendars/$CAL/items" <<'PY'
import os, sys, collections
c = collections.Counter()
for f in os.listdir(sys.argv[1]):
    t = open(os.path.join(sys.argv[1], f), encoding="utf-8").read().replace("\r\n", "\n").replace("\n ", "")
    ev = t.split("BEGIN:VEVENT")[1:]
    for e in ev:
        body = e.split("END:VEVENT")[0]
        n = sum(1 for l in body.split("\n") if l.startswith("RRULE"))
        c[f"VEVENT con {n} RRULE"] += 1
    c["RRULE dentro VTIMEZONE"] += sum(1 for part in t.split("BEGIN:VTIMEZONE")[1:] for l in part.split("END:VTIMEZONE")[0].split("\n") if l.startswith("RRULE"))
print("   " + ", ".join(f"{k}: {v}" for k, v in sorted(c.items())))
PY

echo "12. Riepilogo dal log del core (solo numeri e id):"
grep -E 'CalDAV' "$WORK/core.log" | sed 's/^ */   /' | tail -12
echo "Fine. La cartella temporanea viene cancellata (e ogni prova rimasta su Google eliminata)."
