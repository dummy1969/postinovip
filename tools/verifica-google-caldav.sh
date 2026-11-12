#!/usr/bin/env bash
# Verifica G1: calendari di Google con CalDAV e OAuth2, in SOLA LETTURA (PROPFIND e REPORT; nessun appuntamento cambiato
# o scritto). Core temporaneo senza account; accesso con Google CON il permesso del calendario (si apre il browser);
# «Verifica calendario» del core; poi, con il token di accesso, elenco dei calendari (nome, componenti, permessi di
# scrittura, numero di appuntamenti) e per il calendario principale solo NUMERI e TIPI (ricorrenze, eccezioni, promemoria,
# giornata intera, fusi orari, programmi che li hanno scritti): mai oggetti, luoghi, note o partecipanti.
# Token solo in file 0600 temporanei, mai a schermo; alla fine si buttano (l'account Gmail dell'app non cambia).
#
# Prima: API «CalDAV» attivata nella console Google Cloud dell'app (qualche minuto per attivarsi).
# Uso: tools/verifica-google-caldav.sh [permesso]   (facoltativo, es. https://www.googleapis.com/auth/calendar.events)
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
API=$ROOT/core/src/PostinoVip.Api
[ -x "$API/bin/Debug/net10.0/PostinoVip.Api" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
[ -f "$API/oauth-clients.json" ] || { echo "Manca $API/oauth-clients.json (client ID di Google)"; exit 1; }
SCOPE=${1:-}

WORK=$(mktemp -d -t postinovip-gcaldav-XXXX)
umask 077
PID=
cleanup() { [ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"; }
trap cleanup EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$API"
 export ASPNETCORE_ENVIRONMENT=Production Watch__Enabled=false Cache__Download__Enabled=false Rules__Enabled=false \
   Outbox__Enabled=false Pop3__Enabled=false Cache__Directory="$WORK/cache" Api__Port=5099 \
   Imap__Host=imap.example.invalid Smtp__Host=smtp.example.invalid
 [ -n "$SCOPE" ] && export OAuth__Google__CalendarScope="$SCOPE"
 exec ./bin/Debug/net10.0/PostinoVip.Api > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5099/version && break; sleep 0.2; done
H="Authorization: Bearer $POSTINOVIP_TOKEN"
J() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }

echo "1. Accesso con Google con il permesso del calendario"
START=$(curl -s -H "$H" -H "Content-Type: application/json" -X POST http://127.0.0.1:5099/oauth/start -d '{"provider":"google","calendar":true}')
ID=$(printf '%s' "$START" | J 'print(d.get("id",""))' 2>/dev/null)
URL=$(printf '%s' "$START" | J 'print(d.get("authorizationUrl",""))' 2>/dev/null)
[ -n "$ID" ] || { echo "   NO: accesso non avviato: $START"; tail -5 "$WORK/core.log"; exit 1; }
python3 -I -c 'import sys,urllib.parse as u; print("   permessi chiesti:", u.parse_qs(u.urlparse(sys.argv[1]).query)["scope"][0])' "$URL"
echo "   Si apre il browser: scegli l'account Gmail e PERMETTI l'accesso al calendario (casella da spuntare se c'è)."
xdg-open "$URL" >/dev/null 2>&1 || echo "   Apri a mano questo indirizzo: $URL"
FLOW=
for i in $(seq 150); do
  FLOW=$(curl -s -H "$H" "http://127.0.0.1:5099/oauth/flows/$ID")
  [ "$(printf '%s' "$FLOW" | J 'print(d.get("status",""))' 2>/dev/null)" = pending ] || break
  sleep 2
done
[ "$(printf '%s' "$FLOW" | J 'print(d.get("status",""))' 2>/dev/null)" = done ] || { echo "   NO: accesso non riuscito: $(printf '%s' "$FLOW" | J 'print(d.get("error") or "tempo scaduto")' 2>/dev/null)"; exit 1; }
printf '%s' "$FLOW" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); open(sys.argv[1],"w").write(d["refreshToken"]); print(d.get("email") or "", {True:"sì",False:"NO",None:"non si sa"}[d.get("calendar")])' "$WORK/rt" > "$WORK/who"
unset FLOW
read -r EMAIL GRANTED < "$WORK/who"
echo "   OK: accesso riuscito per $EMAIL"
echo "   permesso del calendario concesso: $GRANTED   (atteso sì)"

echo "2. Verifica calendario del core (scoperta dal principal https://apidata.googleusercontent.com/caldav/v2/<email>/user)"
python3 -I -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"host":"imap.gmail.com","oauthProvider":"google","refreshToken":open(sys.argv[2]).read()}))' "$EMAIL" "$WORK/rt" \
  | curl -s -H "$H" -H "Content-Type: application/json" -X POST http://127.0.0.1:5099/account/test-caldav --data-binary @- \
  | python3 -I -c '
import json,sys
d=json.load(sys.stdin)
print("   OK: calendari che accettano appuntamenti: " + ", ".join("«%s»" % c for c in d.get("calendars") or []) if d.get("ok") else "   NO: %s" % (d.get("error") or d))'

echo "3. Calendari e appuntamenti visti direttamente (sola lettura, solo numeri e tipi)"
python3 -I - "$API/oauth-clients.json" "$WORK/rt" "$EMAIL" <<'PY'
import json, sys, urllib.parse, urllib.request, collections, re, datetime
import xml.etree.ElementTree as ET
c = json.load(open(sys.argv[1])); g = (c.get("OAuth") or c)["Google"]
form = {"grant_type": "refresh_token", "refresh_token": open(sys.argv[2]).read(), "client_id": g["ClientId"]}
if g.get("ClientSecret"): form["client_secret"] = g["ClientSecret"]
tok = json.load(urllib.request.urlopen("https://oauth2.googleapis.com/token", urllib.parse.urlencode(form).encode(), timeout=20))
auth = {"Authorization": "Bearer " + tok["access_token"]}
print("   permessi del token:", tok.get("scope"))
email = sys.argv[3]
BASE = "https://apidata.googleusercontent.com"
D, C, CS = "{DAV:}", "{urn:ietf:params:xml:ns:caldav}", "{http://calendarserver.org/ns/}"

def dav(method, url, body, depth):
    req = urllib.request.Request(urllib.parse.urljoin(BASE, url), data=body.encode(), method=method,
        headers={**auth, "Depth": depth, "Content-Type": "application/xml; charset=utf-8"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, ET.fromstring(r.read())
    except urllib.error.HTTPError as e:
        return e.code, None

def prop(*names):
    return '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/"><d:prop>' + "".join(names) + "</d:prop></d:propfind>"

principal = f"/caldav/v2/{email}/user"
st, x = dav("PROPFIND", principal, prop("<d:current-user-principal/>", "<c:calendar-home-set/>", "<d:displayname/>"), "0")
print(f"   PROPFIND del principal: {st}")
if x is None: sys.exit(0)
home = x.find(f".//{C}calendar-home-set/{D}href")
cup = x.find(f".//{D}current-user-principal/{D}href")
print("   current-user-principal:", "sì" if cup is not None else "no", "· calendar-home-set:", home.text if home is not None else "assente")
if home is None: sys.exit(0)
st, x = dav("PROPFIND", home.text, prop("<d:displayname/>", "<d:resourcetype/>", "<c:supported-calendar-component-set/>",
    "<d:current-user-privilege-set/>", "<cs:getctag/>", "<d:sync-token/>"), "1")
print(f"   PROPFIND della cartella dei calendari: {st}")
cals = []
for r in x.iter(f"{D}response"):
    href = r.find(f"{D}href").text
    if r.find(f".//{D}resourcetype/{C}calendar") is None: continue
    name = (r.findtext(f".//{D}displayname") or "").strip()
    comps = [e.get("name") for e in r.iter(f"{C}comp")]
    privs = {p.tag.split("}")[1] for p in r.findall(f".//{D}current-user-privilege-set/{D}privilege/*")}
    write = "write" in privs or "all" in privs or "write-content" in privs
    cals.append((href, name, comps, write, r.find(f".//{CS}getctag") is not None, r.find(f".//{D}sync-token") is not None))
print(f"   calendari: {len(cals)}")
for href, name, comps, write, ctag, sync in cals:
    st2, y = dav("PROPFIND", href, prop("<d:getetag/>"), "1")
    n = sum(1 for _ in y.iter(f"{D}response")) - 1 if y is not None else "?"
    kind = "principale" if urllib.parse.unquote(href).startswith(f"/caldav/v2/{email}/") else "altro"
    print(f"   - «{name}» ({kind}): componenti {','.join(comps) or '?'}, scrittura {'sì' if write else 'NO'}, "
          f"ctag {'sì' if ctag else 'no'}, sync-token {'sì' if sync else 'no'}, appuntamenti {n}")

main = next((h for h, *_ in cals if urllib.parse.unquote(h).startswith(f"/caldav/v2/{email}/")), None)
if main is None: sys.exit(0)
now = datetime.datetime.now(datetime.timezone.utc)
rng = (now - datetime.timedelta(days=730)).strftime("%Y%m%dT000000Z"), (now + datetime.timedelta(days=365)).strftime("%Y%m%dT000000Z")
q = ('<?xml version="1.0"?><c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-data/></d:prop>'
     f'<c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT"><c:time-range start="{rng[0]}" end="{rng[1]}"/>'
     '</c:comp-filter></c:comp-filter></c:filter></c:calendar-query>')
st, x = dav("REPORT", main, q, "1")
print(f"   REPORT calendar-query del principale (ultimi 2 anni e prossimo): {st}")
if x is None: sys.exit(0)
cnt = collections.Counter(); tz = collections.Counter(); prod = collections.Counter(); files = 0
for cd in x.iter(f"{C}calendar-data"):
    text = (cd.text or "").replace("\r\n", "\n").replace("\n ", "")
    files += 1
    lines = text.split("\n")
    vevents = sum(1 for l in lines if l == "BEGIN:VEVENT")
    cnt["VEVENT"] += vevents
    if vevents > 1: cnt["file con più VEVENT (serie + eccezioni)"] += 1
    for l in lines:
        n = l.split(":", 1)[0].split(";", 1)[0].upper()
        if n in ("RRULE", "RDATE", "EXDATE", "RECURRENCE-ID", "ATTENDEE", "ORGANIZER"): cnt[n] += 1
        if l == "BEGIN:VTIMEZONE": cnt["VTIMEZONE"] += 1
        if l.startswith("BEGIN:VALARM"): cnt["VALARM"] += 1
        if l.upper().startswith("DTSTART;VALUE=DATE:"): cnt["giornata intera"] += 1
        m = re.match(r"DTSTART;.*TZID=([^:;]+)", l, re.I)
        if m: tz[m.group(1)] += 1
        if l.upper().startswith("DTSTART:") and l.endswith("Z"): tz["UTC (…Z)"] += 1
        if l.upper().startswith("PRODID:"): prod[l[7:]] += 1
print(f"   file: {files}; " + ", ".join(f"{k} {v}" for k, v in sorted(cnt.items())))
print("   fusi di DTSTART: " + ", ".join(f"{k} {v}" for k, v in tz.most_common(8)))
print("   PRODID: " + ", ".join(f"{k} {v}" for k, v in prod.most_common(5)))
PY
echo "4. Righe del core su OAuth e CalDAV (senza token):"
grep -iE "oauth|caldav" "$WORK/core.log" | tail -4 | sed 's/^/   /'
echo "Fine. Sola lettura; i token di questa prova si buttano."
