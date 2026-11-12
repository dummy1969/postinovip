#!/usr/bin/env bash
# Verifica C4a: rubriche CardDAV del server di prova, in SOLA LETTURA (PROPFIND e REPORT: nessuna
# modifica). Credenziali dagli user-secrets dell'account "main" (le stesse dell'IMAP), passate a curl in un
# file temporaneo 0600 (mai sulla riga di comando né a schermo), cancellato alla fine.
#
# Uso: tools/verifica-carddav.sh [https://server]   (predefinito: https:// + Imap:Host degli user-secrets)
# Mostra: dove porta la scoperta (.well-known), principal, cartella delle rubriche, rubriche con nome,
# ctag/sync-token e report supportati, numero di contatti, versione vCard e nomi dei primi 3.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
BASE=${1:-https://$(cd "$ROOT/core/src/PostinoVip.Api" && dotnet user-secrets list 2>/dev/null | sed -n 's/^Imap:Host = //p')}
HOST=$(python3 -I -c 'import sys,urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).hostname)' "$BASE")

SECRETS=$(cd "$ROOT/core/src/PostinoVip.Api" && dotnet user-secrets list 2>/dev/null)
USER_=$(printf '%s\n' "$SECRETS" | sed -n 's/^Imap:Username = //p')
PASS=$(printf '%s\n' "$SECRETS" | sed -n 's/^Imap:Password = //p')
unset SECRETS
[ -n "$USER_" ] && [ -n "$PASS" ] || { echo "User-secrets Imap:Username/Imap:Password non trovati"; exit 1; }

WORK=$(mktemp -d -t postinovip-carddav-XXXX)
trap 'rm -rf "$WORK"' EXIT
umask 077
printf 'machine %s login %s password %s\n' "$HOST" "$USER_" "$PASS" > "$WORK/netrc"
unset PASS
echo "Account: $USER_ su $HOST (sola lettura)"

# dav METODO URL PROFONDITÀ CORPO -> corpo della risposta in $WORK/out.xml, stampa codice HTTP e URL finale
dav() {
  curl -sS --max-time 20 --netrc-file "$WORK/netrc" --anyauth -L -X "$1" -H "Depth: $3" \
    -H 'Content-Type: application/xml; charset=utf-8' --data "$4" -o "$WORK/out.xml" \
    -w '%{http_code} %{url_effective}' "$2"
}
xml() { python3 -I "$WORK/x.py" "$@" < "$WORK/out.xml"; }
cat > "$WORK/x.py" <<'PY'
import sys, xml.etree.ElementTree as ET
D = "{DAV:}"; C = "{urn:ietf:params:xml:ns:carddav}"; CS = "{http://calendarserver.org/ns/}"
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
    print(" ".join(hrefs(C + "addressbook-home-set")))
elif what == "tree":
    # Cartelle figlie con il loro tipo (per i server che non indicano il principal, come IceWarp).
    for r in root.iter(D + "response"):
        rt = r.find(f".//{D}resourcetype")
        kinds = [c.tag.split('}')[1] for c in rt] if rt is not None else []
        if "collection" not in kinds: continue
        name = r.findtext(f".//{D}displayname") or ""
        print(f"{r.findtext(D+'href')}\t{name}\t{','.join(kinds)}")
elif what == "books":
    for r in root.iter(D + "response"):
        if r.find(f".//{D}resourcetype/{C}addressbook") is None: continue
        name = r.findtext(f".//{D}displayname") or "(senza nome)"
        ctag = r.findtext(f".//{CS}getctag"); token = r.findtext(f".//{D}sync-token")
        reports = [x.tag.split('}')[1] for x in r.iterfind(f".//{D}supported-report-set/{D}supported-report/{D}report/*")]
        print(f"{r.findtext(D+'href')}\t{name}\tctag={'sì' if ctag else 'no'} sync-token={'sì' if token else 'no'} report={','.join(reports) or '?'}")
elif what == "cards":
    rs = [r for r in root.iter(D + "response") if (r.findtext(D + "href") or "").endswith(".vcf") or r.find(f".//{C}address-data") is not None]
    print(f"   contatti: {len(rs)}")
    for r in rs[:3]:
        data = r.findtext(f".//{C}address-data") or ""
        lines = data.replace("\r\n", "\n").split("\n")
        fn = next((l[3:] for l in lines if l.upper().startswith("FN:")), "(senza FN)")
        ver = next((l[8:] for l in lines if l.upper().startswith("VERSION:")), "?")
        etag = "sì" if r.findtext(f".//{D}getetag") else "no"
        print(f"   - {fn}  (vCard {ver}, ETag {etag})")
PY

echo "1. Scoperta: PROPFIND $BASE/.well-known/carddav"
R=$(dav PROPFIND "$BASE/.well-known/carddav" 0 '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>')
echo "   $R"
PRINCIPAL=$(xml principal)
FOUND=${R#* }
echo "   principal: ${PRINCIPAL:-(nessuno)}"
H_URL=
if [ -n "$PRINCIPAL" ]; then
  case "$PRINCIPAL" in http*) P_URL=$PRINCIPAL ;; *) P_URL=$BASE$PRINCIPAL ;; esac
  echo "2. Cartella delle rubriche (addressbook-home-set)"
  R=$(dav PROPFIND "$P_URL" 0 '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav"><d:prop><c:addressbook-home-set/></d:prop></d:propfind>')
  HOME_=$(xml home)
  echo "   $R -> ${HOME_:-(nessuna)}"
  case "$HOME_" in "") ;; http*) H_URL=$HOME_ ;; *) H_URL=$BASE$HOME_ ;; esac
fi
if [ -z "$H_URL" ]; then
  # Senza principal (IceWarp): si esplorano le cartelle sotto l'indirizzo della scoperta, due livelli.
  echo "2. Nessun principal: esploro le cartelle sotto $FOUND (due livelli, sola lettura)"
  TREEQ='<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:displayname/></d:prop></d:propfind>'
  R=$(dav PROPFIND "$FOUND" 1 "$TREEQ")
  echo "   $R"
  LEVEL1=$(xml tree)
  printf '%s\n' "$LEVEL1" | while IFS=$'\t' read -r href name kinds; do [ -n "$href" ] && echo "   $href  «$name»  [$kinds]"; done
  BOOKDIR=
  for href in $(printf '%s\n' "$LEVEL1" | cut -f1); do
    case "$href" in http*) U=$href ;; *) U=$BASE$href ;; esac
    [ "$U" = "$FOUND" ] && continue
    R=$(dav PROPFIND "$U" 1 "$TREEQ")
    xml tree | while IFS=$'\t' read -r h n k; do
      [ -n "$h" ] && [ "$h" != "$href" ] && echo "      $h  «$n»  [$k]"
    done
    if xml tree | grep -q addressbook; then BOOKDIR=$U; fi
  done
  if printf '%s\n' "$LEVEL1" | grep -q addressbook; then BOOKDIR=$FOUND; fi
  [ -n "$BOOKDIR" ] || { echo "   Nessuna cartella di tipo addressbook in due livelli: incolla questo output."; exit 1; }
  H_URL=$BOOKDIR
fi

echo "3. Rubriche"
R=$(dav PROPFIND "$H_URL" 1 '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/"><d:prop><d:resourcetype/><d:displayname/><cs:getctag/><d:sync-token/><d:supported-report-set/></d:prop></d:propfind>')
echo "   $R"
BOOKS=$(xml books)
[ -n "$BOOKS" ] || { echo "   nessuna rubrica trovata"; head -c 800 "$WORK/out.xml"; echo; exit 1; }
printf '%s\n' "$BOOKS" | while IFS=$'\t' read -r href name info; do echo "   $name  ($href)  $info"; done

echo "4. Contatti di ogni rubrica (REPORT addressbook-query, solo lettura)"
printf '%s\n' "$BOOKS" | while IFS=$'\t' read -r href name info; do
  case "$href" in http*) B_URL=$href ;; *) B_URL=$BASE$href ;; esac
  R=$(dav REPORT "$B_URL" 1 '<?xml version="1.0"?><c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav"><d:prop><d:getetag/><c:address-data/></d:prop></c:addressbook-query>')
  echo "   $name: $R"
  xml cards
done
echo "Fatto: nessuna modifica alla rubrica del server."
