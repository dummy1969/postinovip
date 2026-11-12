#!/usr/bin/env bash
# Verifica K1: calendari CalDAV del server di prova, in SOLA LETTURA (PROPFIND e REPORT: nessuna modifica).
# Credenziali dagli user-secrets dell'account "main" (le stesse dell'IMAP), passate a curl in un file temporaneo
# 0600 (mai sulla riga di comando né a schermo), cancellato alla fine.
#
# Uso: tools/verifica-caldav.sh [https://server]   (predefinito: https:// + Imap:Host degli user-secrets)
# Mostra: dove porta la scoperta (.well-known/caldav), principal, cartella dei calendari, calendari con nome, colore,
# tipi di elemento (eventi, attività), ctag/sync-token e report supportati; per ogni calendario solo NUMERI e TIPI:
# eventi, attività, ricorrenti (RRULE, RDATE, EXDATE, occorrenze modificate), giornata intera, promemoria (VALARM),
# fusi orari usati, programmi che li hanno creati (PRODID), anni coperti. Mai oggetti, luoghi, note o partecipanti.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
BASE=${1:-https://$(cd "$ROOT/core/src/PostinoVip.Api" && dotnet user-secrets list 2>/dev/null | sed -n 's/^Imap:Host = //p')}
HOST=$(python3 -I -c 'import sys,urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).hostname)' "$BASE")

SECRETS=$(cd "$ROOT/core/src/PostinoVip.Api" && dotnet user-secrets list 2>/dev/null)
USER_=$(printf '%s\n' "$SECRETS" | sed -n 's/^Imap:Username = //p')
PASS=$(printf '%s\n' "$SECRETS" | sed -n 's/^Imap:Password = //p')
unset SECRETS
[ -n "$USER_" ] && [ -n "$PASS" ] || { echo "User-secrets Imap:Username/Imap:Password non trovati"; exit 1; }

WORK=$(mktemp -d -t postinovip-caldav-XXXX)
trap 'rm -rf "$WORK"' EXIT
umask 077
printf 'machine %s login %s password %s\n' "$HOST" "$USER_" "$PASS" > "$WORK/netrc"
unset PASS
echo "Account: $USER_ su $HOST (sola lettura)"

# dav METODO URL PROFONDITÀ CORPO -> corpo della risposta in $WORK/out.xml, stampa codice HTTP e URL finale
dav() {
  curl -sS --max-time 60 --netrc-file "$WORK/netrc" --anyauth -L -X "$1" -H "Depth: $3" \
    -H 'Content-Type: application/xml; charset=utf-8' --data "$4" -o "$WORK/out.xml" \
    -w '%{http_code} %{url_effective}' "$2"
}
xml() { python3 -I "$WORK/x.py" "$@" < "$WORK/out.xml"; }
cat > "$WORK/x.py" <<'PY'
import sys, re, collections, xml.etree.ElementTree as ET
D = "{DAV:}"; C = "{urn:ietf:params:xml:ns:caldav}"; CS = "{http://calendarserver.org/ns/}"; A = "{http://apple.com/ns/ical/}"
try:
    root = ET.fromstring(sys.stdin.read())
except ET.ParseError as e:
    print("   (risposta non XML:", e, ")"); sys.exit(0)
what = sys.argv[1]
def hrefs(tag):
    return [h.text for p in root.iter(tag) for h in p.iter(D + "href")]
if what == "principal":
    print(" ".join(hrefs(D + "current-user-principal")))
elif what == "home":
    print(" ".join(hrefs(C + "calendar-home-set")))
elif what == "tree":
    for r in root.iter(D + "response"):
        rt = r.find(f".//{D}resourcetype")
        kinds = [c.tag.split('}')[1] for c in rt] if rt is not None else []
        if "collection" not in kinds: continue
        name = r.findtext(f".//{D}displayname") or ""
        print(f"{r.findtext(D+'href')}\t{name}\t{','.join(kinds)}")
elif what == "calendars":
    for r in root.iter(D + "response"):
        if r.find(f".//{D}resourcetype/{C}calendar") is None: continue
        name = r.findtext(f".//{D}displayname") or "(senza nome)"
        color = r.findtext(f".//{A}calendar-color") or "-"
        comps = [c.get("name") for c in r.iterfind(f".//{C}supported-calendar-component-set/{C}comp")]
        ctag = r.findtext(f".//{CS}getctag"); token = r.findtext(f".//{D}sync-token")
        reports = [x.tag.split('}')[1] for x in r.iterfind(f".//{D}supported-report-set/{D}supported-report/{D}report/*")]
        tz = "sì" if (r.findtext(f".//{C}calendar-timezone") or "").strip() else "no"
        print(f"{r.findtext(D+'href')}\t{name}\tcolore={color} elementi={','.join(comps) or '?'} ctag={'sì' if ctag else 'no'} "
              f"sync-token={'sì' if token else 'no'} fuso-del-calendario={tz} report={','.join(reports) or '?'}")
elif what == "items":
    # Solo numeri e tipi: nessun oggetto, luogo, nota o partecipante viene stampato.
    rs = list(root.iter(D + "response"))
    stats = collections.Counter(); tzids = collections.Counter(); prodids = collections.Counter(); years = []
    for r in rs:
        data = r.findtext(f".//{C}calendar-data") or ""
        if not data: continue
        stats["oggetti"] += 1
        if r.findtext(f".//{D}getetag"): stats["con ETag"] += 1
        text = re.sub(r"\r?\n[ \t]", "", data)          # righe ripiegate (RFC 5545 3.1)
        lines = text.replace("\r\n", "\n").split("\n")
        comp = None
        for l in lines:
            u = l.upper()
            name = u.split(":", 1)[0].split(";", 1)[0]
            if u.startswith("BEGIN:"):
                comp = u[6:]
                if comp in ("VEVENT", "VTODO", "VJOURNAL", "VALARM", "VTIMEZONE"): stats[comp] += 1
            elif u.startswith("END:"): comp = None
            elif name == "PRODID":
                prodids[l.split(":", 1)[1].strip()[:60]] += 1
            elif comp in ("VEVENT", "VTODO"):
                if name == "RRULE":
                    stats["ricorrenti (RRULE)"] += 1
                    freq = re.search(r"FREQ=([A-Z]+)", u); stats["FREQ=" + (freq.group(1) if freq else "?")] += 1
                    if "COUNT=" in u: stats["con COUNT"] += 1
                    if "UNTIL=" in u: stats["con UNTIL"] += 1
                    if "BYSETPOS=" in u or re.search(r"BYDAY=[^;]*[0-9-]", u): stats["regole complesse (BYSETPOS / BYDAY con numero)"] += 1
                elif name == "RDATE": stats["con RDATE"] += 1
                elif name == "EXDATE": stats["con EXDATE"] += 1
                elif name == "RECURRENCE-ID": stats["occorrenze modificate (RECURRENCE-ID)"] += 1
                elif name == "ATTENDEE": stats["con partecipanti (ATTENDEE)"] += 1
                elif name == "DTSTART":
                    params = l.split(":", 1)[0]
                    if "VALUE=DATE" in params.upper() and "VALUE=DATE-TIME" not in params.upper(): stats["giornata intera"] += 1
                    m = re.search(r"TZID=([^;:]+)", params)
                    if m: tzids[m.group(1)] += 1
                    elif l.rstrip().endswith("Z"): tzids["(UTC, con Z)"] += 1
                    elif "VALUE=DATE" not in params.upper(): tzids["(ora locale senza fuso)"] += 1
                    y = re.search(r":(\d{4})", l)
                    if y: years.append(int(y.group(1)))
    print(f"   oggetti iCalendar: {stats['oggetti']} (con ETag: {stats['con ETag']})")
    for k in ["VEVENT", "VTODO", "VJOURNAL", "VALARM", "VTIMEZONE", "giornata intera", "ricorrenti (RRULE)", "con COUNT", "con UNTIL",
              "regole complesse (BYSETPOS / BYDAY con numero)", "con RDATE", "con EXDATE", "occorrenze modificate (RECURRENCE-ID)",
              "con partecipanti (ATTENDEE)"]:
        if stats[k]: print(f"   {k}: {stats[k]}")
    freqs = {k: v for k, v in stats.items() if k.startswith("FREQ=")}
    if freqs: print("   frequenze: " + ", ".join(f"{k[5:]} {v}" for k, v in sorted(freqs.items())))
    if tzids: print("   fusi orari di DTSTART: " + ", ".join(f"{k} ({v})" for k, v in tzids.most_common(6)))
    if prodids: print("   creati da: " + "; ".join(f"{k} ({v})" for k, v in prodids.most_common(4)))
    if years: print(f"   anni di inizio: dal {min(years)} al {max(years)}")
PY

echo "1. Scoperta: PROPFIND $BASE/.well-known/caldav"
R=$(dav PROPFIND "$BASE/.well-known/caldav" 0 '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>')
echo "   $R"
PRINCIPAL=$(xml principal)
FOUND=${R#* }
echo "   principal: ${PRINCIPAL:-(nessuno)}"
H_URL=
if [ -n "$PRINCIPAL" ]; then
  case "$PRINCIPAL" in http*) P_URL=$PRINCIPAL ;; *) P_URL=$BASE$PRINCIPAL ;; esac
  echo "2. Cartella dei calendari (calendar-home-set)"
  R=$(dav PROPFIND "$P_URL" 0 '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-home-set/></d:prop></d:propfind>')
  HOME_=$(xml home)
  echo "   $R -> ${HOME_:-(nessuna)}"
  case "$HOME_" in "") ;; http*) H_URL=$HOME_ ;; *) H_URL=$BASE$HOME_ ;; esac
fi
if [ -z "$H_URL" ]; then
  # Senza principal (come IceWarp per i contatti): cartelle sotto l'indirizzo della scoperta, due livelli.
  echo "2. Nessun principal: esploro le cartelle sotto $FOUND (due livelli, sola lettura)"
  TREEQ='<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:displayname/></d:prop></d:propfind>'
  R=$(dav PROPFIND "$FOUND" 1 "$TREEQ")
  echo "   $R"
  LEVEL1=$(xml tree)
  printf '%s\n' "$LEVEL1" | while IFS=$'\t' read -r href name kinds; do [ -n "$href" ] && echo "   $href  «$name»  [$kinds]"; done
  CALDIR=
  for href in $(printf '%s\n' "$LEVEL1" | cut -f1); do
    case "$href" in http*) U=$href ;; *) U=$BASE$href ;; esac
    [ "$U" = "$FOUND" ] && continue
    R=$(dav PROPFIND "$U" 1 "$TREEQ")
    xml tree | while IFS=$'\t' read -r h n k; do
      [ -n "$h" ] && [ "$h" != "$href" ] && echo "      $h  «$n»  [$k]"
    done
    if xml tree | grep -q -w calendar; then CALDIR=$U; fi
  done
  if printf '%s\n' "$LEVEL1" | grep -q -w calendar; then CALDIR=$FOUND; fi
  [ -n "$CALDIR" ] || { echo "   Nessuna cartella di tipo calendar in due livelli: incolla questo output."; exit 1; }
  H_URL=$CALDIR
fi

echo "3. Calendari"
R=$(dav PROPFIND "$H_URL" 1 '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:a="http://apple.com/ns/ical/"><d:prop><d:resourcetype/><d:displayname/><a:calendar-color/><c:supported-calendar-component-set/><c:calendar-timezone/><cs:getctag/><d:sync-token/><d:supported-report-set/></d:prop></d:propfind>')
echo "   $R"
CALS=$(xml calendars)
[ -n "$CALS" ] || { echo "   nessun calendario trovato"; head -c 800 "$WORK/out.xml"; echo; exit 1; }
printf '%s\n' "$CALS" | while IFS=$'\t' read -r href name info; do echo "   «$name»  ($href)"; echo "      $info"; done

echo "4. Contenuto di ogni calendario (REPORT calendar-query, solo lettura; solo numeri e tipi)"
printf '%s\n' "$CALS" | while IFS=$'\t' read -r href name info; do
  case "$href" in http*) C_URL=$href ;; *) C_URL=$BASE$href ;; esac
  R=$(dav REPORT "$C_URL" 1 '<?xml version="1.0"?><c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><d:getetag/><c:calendar-data/></d:prop><c:filter><c:comp-filter name="VCALENDAR"/></c:filter></c:calendar-query>')
  echo "   «$name»: $R"
  xml items
done
echo "Fatto: nessuna modifica ai calendari del server."
