#!/usr/bin/env bash
# Verifica C4d-b: sincronizzazione CardDAV nei due sensi con la rubrica VERA di Google, con OAuth2.
# MODIFICA LA RUBRICA DI GOOGLE, ma solo con contatti di prova creati qui (nome «PostinoVip Prova…», indirizzo
# prova-carddav-…@example.invalid), eliminati alla fine (anche se lo script si interrompe). I contatti già presenti
# vengono solo copiati nella cartella di cache TEMPORANEA (cancellata alla fine) e contati, mai modificati.
# La cache vera dell'app e il suo account Gmail non vengono toccati.
# Token: accesso con Google nel browser (con il permesso dei contatti); token di rinnovo e di accesso solo in file 0600
# temporanei (al core per variabile d'ambiente, a curl con -H @file), mai sulla riga di comando né a schermo.
#
# Uso: tools/verifica-google-carddav-sync.sh
# Passi: 1 accesso; 2 prima sincronizzazione (contatti di Google copiati); 3 contatto nuovo dall'app -> Google (PUT o
# POST); 4 modifica dall'app -> Google; 5 modifica da «un altro programma» su Google -> computer; 6 eliminazione
# dall'app -> Google; 7 contatto creato ed eliminato su Google -> computer.
# Passo 3 con la diagnosi dell'indirizzo (0.0.143: Google risponde al PUT con 201 e Location = il suo id; dal 0.0.144 il
# core usa quello: «coincidono: sì»).
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
API=$ROOT/core/src/PostinoVip.Api
[ -x "$API/bin/Debug/net10.0/PostinoVip.Api" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
[ -f "$API/oauth-clients.json" ] || { echo "Manca $API/oauth-clients.json (client ID di Google)"; exit 1; }

echo "Questa prova MODIFICA LA RUBRICA DI GOOGLE: crea, cambia ed elimina due contatti di prova."
echo "I contatti già presenti non vengono toccati. Alla fine i contatti di prova sono eliminati."
read -r -p "Continuare? [s/N] " ok
[ "$ok" = s ] || [ "$ok" = S ] || { echo "Annullato."; exit 0; }

WORK=$(mktemp -d -t postinovip-gcarddav-sync-XXXX)
umask 077
PID=
HREFS=()
GHOST=www.googleapis.com
srv() { local m=$1 u=$2; shift 2   # srv METODO url-o-percorso [opzioni curl...] -> codice HTTP, corpo in srv.out
  case $u in http*) ;; *) u="https://$GHOST$u";; esac
  curl -s --max-time 20 -H @"$WORK/auth.hdr" -X "$m" -o "$WORK/srv.out" -D "$WORK/srv.hdr" -w '%{http_code}' "$@" "$u"; }
cleanup() {
  [ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }
  if [ -f "$WORK/auth.hdr" ]; then
    for h in "${HREFS[@]}"; do
      c=$(srv DELETE "$h"); [ "$c" = 404 ] || [ "$c" = 410 ] || echo "   pulizia: DELETE $h -> $c"
    done
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
H="Authorization: Bearer $POSTINOVIP_TOKEN"
J() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }
code() { curl -s -o /dev/null -w "%{http_code}" -H "$H" "$@"; }
core() {   # avvia il core; variabili in più da "$WORK/env" (righe NOME=valore, lette dalla sotto-shell)
  (cd "$API"
   export ASPNETCORE_ENVIRONMENT=Production Watch__Enabled=false Cache__Download__Enabled=false Rules__Enabled=false \
     Outbox__Enabled=false Pop3__Enabled=false Cache__Directory="$WORK/cache" Api__Port=5099
   if [ -f "$WORK/env" ]; then while IFS='=' read -r k v; do export "$k=$v"; done < "$WORK/env"; fi
   exec ./bin/Debug/net10.0/PostinoVip.Api > "$WORK/core.log" 2>&1) &
  PID=$!
  for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5099/version && break; sleep 0.2; done
}
stop() { kill $PID 2>/dev/null; wait $PID 2>/dev/null; PID=; }

echo "1. Accesso con Google con il permesso dei contatti (si apre il browser)"
Imap__Host=imap.example.invalid Smtp__Host=smtp.example.invalid core
START=$(curl -s -H "$H" -H "Content-Type: application/json" -X POST http://127.0.0.1:5099/oauth/start -d '{"provider":"google","contacts":true}')
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
printf '%s' "$FLOW" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); open(sys.argv[1],"w").write(d["refreshToken"]); print(d.get("email") or "", "sì" if d.get("contacts") else "NO")' "$WORK/rt" > "$WORK/who"
unset FLOW
read -r EMAIL GRANTED < "$WORK/who"
echo "   accesso riuscito per $EMAIL, permesso dei contatti: $GRANTED   (atteso sì)"
[ "$GRANTED" = sì ] || exit 1
stop
# token di accesso per le prove «da un altro programma» (curl), dal token di rinnovo
python3 -I - "$API/oauth-clients.json" "$WORK/rt" "$WORK/auth.hdr" <<'PY' || { echo "   NO: token di accesso non ottenuto"; exit 1; }
import json, sys, urllib.parse, urllib.request
c = json.load(open(sys.argv[1]))
g = (c.get("OAuth") or c)["Google"]
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
     "Smtp__Security": "StartTls", "OAuth__Provider": "google", "OAuth__RefreshToken": rt, "CardDav__Enabled": "true"}
open(sys.argv[1], "w").write("".join(f"Accounts__0__{k}={x}\n" for k, x in v.items()))
PY
core
B=http://127.0.0.1:5099/accounts/gm
st() { curl -s -H "$H" "$B/contacts/sync"; }
STATE=$WORK/cache/accounts/gm/carddav.json
etag() { sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$WORK/srv.hdr" | tr -d '\r'; }
hrefOf() { python3 -I -c 'import json,sys; s=json.load(open(sys.argv[1])); print(next((e["href"] for e in s["entries"] if e.get("contactId")==sys.argv[2]), ""))' "$STATE" "$1"; }
local_notes() { curl -s -H "$H" "$B/contacts" | J "print(next((c.get('notes') or '(vuote)' for c in d['items'] if '$1' in [e['address'] for e in c['emails']]), '(assente)'))"; }
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

echo "2. Prima sincronizzazione (scoperta da https://$GHOST/.well-known/carddav):"
for i in $(seq 300); do s=$(st | J 'print(d["state"])'); [ "$s" = waiting ] || [ "$s" = syncing ] || break; sleep 0.2; done
st | J 'print("   stato %s, rubrica «%s», conferma richiesta: %s%s" % (d["state"], d.get("addressBook"), "sì" if d["needsConfirmation"] else "no", (" - " + d["error"]) if d.get("error") else ""))'
[ "$(st | J 'print(d["state"])')" = ok ] || { echo "   Sincronizzazione non riuscita: log del core in fondo."; tail -20 "$WORK/core.log"; exit 1; }
BOOK=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["book"])' "$STATE")
echo "   rubrica: $BOOK"
echo "   contatti di Google copiati qui: $(curl -s -H "$H" "$B/contacts" | J 'print(len(d["items"]))')   (atteso: quanti ne hai su Google; conferma: no)"

# hrefs della rubrica su Google (PROPFIND Depth 1, solo indirizzi), uno per riga, così come li scrive Google
hrefs() { srv PROPFIND "$BOOK" -H 'Depth: 1' -H 'Content-Type: application/xml; charset=utf-8' \
  --data '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getetag/></d:prop></d:propfind>' > /dev/null
  python3 -I -c '
import sys, xml.etree.ElementTree as ET
for r in ET.parse(sys.argv[1]).getroot().iter("{DAV:}href"): print(r.text.strip())' "$WORK/srv.out" | sort; }
echo "3. Contatto nuovo dall'app (diagnosi: indirizzi della rubrica prima e dopo):"
hrefs > "$WORK/before.txt"
echo "   indirizzi su Google: $(wc -l < "$WORK/before.txt"), di cui con %40: $(grep -c '%40' "$WORK/before.txt"), con @: $(grep -c '@' "$WORK/before.txt")"
echo "   esempio (solo la forma, l'ultimo pezzo nascosto): $(sed -n 2p "$WORK/before.txt" | sed 's#[^/]*$#…#')"
LS=$(st | J 'print(d.get("lastSync") or "")')
ID=$(curl -s -H "$H" -H "Content-Type: application/json" -X POST "$B/contacts" \
  -d "{\"givenName\":\"PostinoVip\",\"familyName\":\"Prova $TAG\",\"emails\":[{\"address\":\"$MAIL1\"}],\"notes\":\"creato dall'app\"}" | J 'print(d["id"])')
# la sincronizzazione parte da sola 2 s dopo la modifica: si aspetta quella, senza chiederne un'altra
for i in $(seq 150); do now=$(st | J 'print(d.get("lastSync") or "")'); [ -n "$now" ] && [ "$now" != "$LS" ] && break; sleep 0.2; done
H1=$(hrefOf "$ID")
hrefs > "$WORK/after.txt"
comm -13 "$WORK/before.txt" "$WORK/after.txt" > "$WORK/new.txt"
# per la pulizia solo quelli che sono davvero il contatto di prova (un contatto vero aggiunto intanto non si tocca)
: > "$WORK/mine.txt"
while read -r h; do srv GET "$h" > /dev/null; grep -q "$MAIL1" "$WORK/srv.out" && { HREFS+=("$h"); echo "$h" >> "$WORK/mine.txt"; }; done < "$WORK/new.txt"
echo "   log del core: $(grep -o 'CardDAV: elemento [^ ]* caricato.*' "$WORK/core.log" | tail -1 | sed 's/elemento [^ ]* //')"
echo "   indirizzo segnato dal core: $(printf '%s' "$H1" | sed 's#.*/##')"
echo "   indirizzi nuovi su Google con il contatto di prova: $(wc -l < "$WORK/mine.txt") -> $(sed 's#.*/##' "$WORK/mine.txt" | tr '\n' ' ')"
grep -qxF "$H1" "$WORK/mine.txt" && echo "   coincidono: sì   (atteso sì)" || echo "   coincidono: NO (Google lo tiene a un altro indirizzo)"
[ -n "$H1" ] && ! grep -qxF "$H1" "$WORK/mine.txt" && HREFS+=("$H1")
[ -s "$WORK/mine.txt" ] && H1=$(head -1 "$WORK/mine.txt")
echo "   GET $(srv GET "$H1")   (atteso 200)"
grep -q "$MAIL1" "$WORK/srv.out" && echo "   contiene l'indirizzo: sì   (atteso sì)" || echo "   contiene l'indirizzo: NO"
echo "   righe del vCard su Google: $(tr -d '\r' < "$WORK/srv.out" | sed -n 's/^\([A-Za-z-]*\)[;:].*/\1/p' | sort -u | tr '\n' ' ')"
echo "   UID su Google: $(tr -d '\r' < "$WORK/srv.out" | grep -qi '^UID:' && echo presente || echo assente)"

echo "4. Modifica dall'app:"
curl -s -o /dev/null -H "$H" -H "Content-Type: application/json" -X PUT "$B/contacts/$ID" \
  -d "{\"givenName\":\"PostinoVip\",\"familyName\":\"Prova $TAG\",\"emails\":[{\"address\":\"$MAIL1\"}],\"notes\":\"cambiato dall'app\"}"
giro
srv GET "$H1" > /dev/null
grep -q "cambiato dall'app" "$WORK/srv.out" && echo "   nota su Google: cambiata   (atteso cambiata)" || echo "   nota su Google: NON cambiata"

echo "5. Modifica da «un altro programma» su Google:"
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
echo "   ETag letto: $([ -n "$E" ] && echo sì || echo NO)   PUT con If-Match: $(srv PUT "$H1" -H "If-Match: $E" -H 'Content-Type: text/vcard; charset=utf-8' --data-binary @"$WORK/mod.vcf")   (atteso 204 o 200)"
giro
echo "   nota sul computer: $(local_notes "$MAIL1")   (atteso cambiato sul server)"

echo "6. Eliminazione dall'app:"
echo "   DELETE nell'app: $(code -X DELETE "$B/contacts/$ID")   (atteso 204)"
giro
echo "   su Google: GET $(srv GET "$H1")   (atteso 404)"

echo "7. Contatto creato ed eliminato su Google (POST, come la documentazione di Google):"
printf 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:PostinoVip Prova server %s\r\nN:Prova server %s;PostinoVip;;;\r\nEMAIL;TYPE=INTERNET:%s\r\nEND:VCARD\r\n' \
  "$TAG" "$TAG" "$MAIL2" > "$WORK/new.vcf"
echo "   POST nuovo: $(srv POST "$BOOK" -H 'Content-Type: text/vcard; charset=utf-8' --data-binary @"$WORK/new.vcf")   (atteso 201)"
H2=$(sed -n 's/^[Ll]ocation: *//p' "$WORK/srv.hdr" | tr -d '\r')
[ -n "$H2" ] && HREFS+=("$H2")
echo "   Invia/ricevi: $(code -X POST "$B/receive")   (atteso 202)"
giro
echo "   sul computer: $(local_notes "$MAIL2" | sed 's/(vuote)/presente/')   (atteso presente)"
if [ -n "$H2" ]; then echo "   DELETE su Google: $(srv DELETE "$H2")   (atteso 204 o 200)"; else echo "   (Location assente: non eliminato qui, lo toglie la pulizia se possibile)"; fi
giro
echo "   sul computer: $(local_notes "$MAIL2" | sed 's/(vuote)/presente/')   (atteso assente)"

echo "8. Riepilogo dal log del core (solo numeri e id):"
grep -E 'CardDAV' "$WORK/core.log" | sed 's/^ */   /' | tail -12
echo "Fine. Contatti di prova eliminati; la cartella temporanea e i token di questa prova vengono cancellati."
