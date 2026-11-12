#!/usr/bin/env bash
# Verifica C4d-a: rubrica di Google con CardDAV e OAuth2, in SOLA LETTURA (scoperta e nome della rubrica, nessun contatto
# letto, cambiato o scritto). Avvia un core temporaneo (nessun account di posta, cache in una cartella temporanea), chiede
# un accesso con Google CON il permesso dei contatti (si apre il browser), poi «Verifica rubrica» con quel token.
# Il token di rinnovo resta in memoria e in un file 0600 temporaneo, mai a schermo; alla fine si butta (l'account Gmail
# dell'app non cambia: il suo token resta quello di prima).
#
# Prima: nella console Google Cloud dell'app, API CardDAV attivata e permesso dei contatti aggiunto (passi in chat).
# Uso: tools/verifica-google-carddav.sh [permesso]   (permesso facoltativo, es. https://www.googleapis.com/auth/contacts)
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
API=$ROOT/core/src/PostinoVip.Api
[ -x "$API/bin/Debug/net10.0/PostinoVip.Api" ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
[ -f "$API/oauth-clients.json" ] || { echo "Manca $API/oauth-clients.json (client ID di Google)"; exit 1; }
SCOPE=${1:-}

WORK=$(mktemp -d -t postinovip-gcarddav-XXXX)
umask 077
PID=
cleanup() { [ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$WORK"; }
trap cleanup EXIT

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
(cd "$API" && exec env ASPNETCORE_ENVIRONMENT=Production Watch__Enabled=false Cache__Download__Enabled=false \
  Rules__Enabled=false Outbox__Enabled=false Pop3__Enabled=false Cache__Directory="$WORK/cache" Api__Port=5099 \
  Imap__Host=imap.example.invalid Smtp__Host=smtp.example.invalid ${SCOPE:+OAuth__Google__ContactsScope="$SCOPE"} \
  ./bin/Debug/net10.0/PostinoVip.Api > "$WORK/core.log" 2>&1) &
PID=$!
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5099/version && break; sleep 0.2; done
H="Authorization: Bearer $POSTINOVIP_TOKEN"
J() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }

echo "1. Accesso con Google con il permesso dei contatti${SCOPE:+ ($SCOPE)}"
START=$(curl -s -H "$H" -H "Content-Type: application/json" -X POST http://127.0.0.1:5099/oauth/start -d '{"provider":"google","contacts":true}')
ID=$(printf '%s' "$START" | J 'print(d.get("id",""))' 2>/dev/null)
URL=$(printf '%s' "$START" | J 'print(d.get("authorizationUrl",""))' 2>/dev/null)
[ -n "$ID" ] || { echo "   NO: accesso non avviato: $START"; tail -5 "$WORK/core.log"; exit 1; }
python3 -I -c 'import sys,urllib.parse as u; print("   permessi chiesti:", u.parse_qs(u.urlparse(sys.argv[1]).query)["scope"][0])' "$URL"
echo "   Si apre il browser: scegli l'account Gmail, PERMETTI l'accesso ai contatti (casella da spuntare se c'è)."
xdg-open "$URL" >/dev/null 2>&1 || echo "   Apri a mano questo indirizzo: $URL"

FLOW=
for i in $(seq 150); do
  FLOW=$(curl -s -H "$H" "http://127.0.0.1:5099/oauth/flows/$ID")
  s=$(printf '%s' "$FLOW" | J 'print(d.get("status",""))' 2>/dev/null)
  [ "$s" = pending ] || break
  sleep 2
done
s=$(printf '%s' "$FLOW" | J 'print(d.get("status",""))' 2>/dev/null)
[ "$s" = done ] || { echo "   NO: accesso non riuscito: $(printf '%s' "$FLOW" | J 'print(d.get("error") or d.get("status") or "tempo scaduto")' 2>/dev/null)"; exit 1; }
printf '%s' "$FLOW" | python3 -I -c 'import json,sys; open(sys.argv[1],"w").write(json.load(sys.stdin)["refreshToken"])' "$WORK/rt"
EMAIL=$(printf '%s' "$FLOW" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("email") or "")')
GRANTED=$(printf '%s' "$FLOW" | python3 -I -c 'import json,sys; c=json.load(sys.stdin).get("contacts"); print({True:"sì",False:"NO",None:"non si sa"}[c])')
unset FLOW
echo "   OK: accesso riuscito per $EMAIL"
echo "   permesso dei contatti concesso: $GRANTED"

echo "2. Verifica rubrica (sola lettura: PROPFIND della scoperta e della rubrica)"
BODY=$(python3 -I -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"host":"imap.gmail.com","oauthProvider":"google","refreshToken":open(sys.argv[2]).read()}))' "$EMAIL" "$WORK/rt")
RES=$(printf '%s' "$BODY" | curl -s -H "$H" -H "Content-Type: application/json" -X POST http://127.0.0.1:5099/account/test-carddav --data-binary @-)
unset BODY
printf '%s' "$RES" | python3 -I -c '
import json,sys
d=json.load(sys.stdin)
if d.get("ok"):
    print("   OK: trovata la rubrica «%s»" % d.get("addressBook"))
    print("   indirizzo:", d.get("url"))
else:
    print("   NO:", d.get("error") or d)'
echo "3. Righe del core su OAuth e CardDAV (senza token):"
grep -iE "oauth|carddav|dav" "$WORK/core.log" | grep -v -i "bearer" | tail -5 | sed 's/^/   /'
echo "Fine. Il token di questa prova si butta: l'account Gmail dell'app non cambia."
