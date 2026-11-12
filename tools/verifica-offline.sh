#!/usr/bin/env bash
# Verifica 8d-1: il core senza rete usa la copia locale.
# Avvia il core di sviluppo (account "main", cache in ~/.local/share/postinovip-dev) con IMAP e SMTP
# puntati a un server che non c'è, prova le richieste dell'app e stampa cosa succede, poi lo chiude.
# Non modifica la configurazione né la casella: il server vero non viene mai contattato.
#   tools/verifica-offline.sh            porta chiusa su questo PC (collegamento rifiutato subito)
#   tools/verifica-offline.sh lento      server che accetta la connessione ma non risponde mai
#                                        (prova il tempo massimo di 10 s per IMAP e 15 s per SMTP)
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
LOG=$(mktemp -t postinovip-offline-XXXX.log)

SILENT=
if [ "${1:-}" = "lento" ]; then
  # Server muto su questo PC: accetta le connessioni e non manda mai il saluto IMAP/SMTP.
  HOST=127.0.0.1
  PORT=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  python3 -I -c "
import socket, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', $PORT)); s.listen(16); held = []
while True:
    c, _ = s.accept(); held.append(c)
" &
  SILENT=$!
else
  HOST=127.0.0.1                # porta libera: nessuno ascolta
  PORT=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
fi

export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
cd "$ROOT/core/src/PostinoVip.Api" || exit 1
[ -x bin/Debug/net10.0/PostinoVip.Api ] || { echo "Core non compilato: cd core && dotnet build"; exit 1; }
ASPNETCORE_ENVIRONMENT=Development Watch__Enabled=false Cache__Download__Enabled=false Api__Port=5094 \
  Imap__Host=$HOST Imap__Port=$PORT Smtp__Host=$HOST Smtp__Port=$PORT \
  ./bin/Debug/net10.0/PostinoVip.Api > "$LOG" 2>&1 &
PID=$!; trap 'kill $PID $SILENT 2>/dev/null; rm -f "$LOG"' EXIT
for i in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:5094/version && break; sleep 0.2; done

echo "Server finto: $HOST:$PORT (cache: ~/.local/share/postinovip-dev/accounts/main)"
python3 -I - 5094 "$POSTINOVIP_TOKEN" "$HOME/.local/share/postinovip-dev/accounts/main/index.db" <<'PY'
import json, sqlite3, sys, time, urllib.parse, urllib.request
port, token, db = sys.argv[1], sys.argv[2], sys.argv[3]

def call(method, path, body=None):
    req = urllib.request.Request(f"http://127.0.0.1:{port}{path}", method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    t = time.perf_counter()
    try:
        with urllib.request.urlopen(req) as r:
            status, data = r.status, json.load(r)
    except urllib.error.HTTPError as e:
        status, data = e.code, json.load(e)
    return status, data, time.perf_counter() - t

def show(what, method, path, body=None, summary=lambda d: ""):
    status, data, t = call(method, path, body)
    detail = summary(data) if status == 200 else f"{data.get('title')}: {data.get('detail')}"
    print(f"{what:<38} {status}  {t:5.2f} s  {detail}")
    return data

ro = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
cached = ro.execute("select uid from messages m join folders f on f.id=m.folder_id where f.full_name='INBOX' and body_sha256 is not null order by uid desc limit 1").fetchone()
missing = ro.execute("select uid from messages m join folders f on f.id=m.folder_id where f.full_name='INBOX' and body_sha256 is null order by uid limit 1").fetchone()

online = lambda d: ", ".join(f"{a['id']} online={a['online']}" for a in d)
show("Account (prima)", "GET", "/accounts", summary=online)
show("Cartelle", "GET", "/folders", summary=lambda d: f"{len(d)} cartelle dalla copia locale, INBOX {next((f['count'] for f in d if f['fullName']=='INBOX'), '?')}")
show("Account (dopo)", "GET", "/accounts", summary=online)
show("Lista INBOX", "GET", "/folders/INBOX/messages?limit=50", summary=lambda d: f"{d['total']} mail, prima: {d['items'][0]['subject'][:40]!r}")
show("Lista INBOX, di nuovo", "GET", "/folders/INBOX/messages?offset=50&limit=50", summary=lambda d: f"{len(d['items'])} mail (nessun nuovo tentativo)")
if cached:
    show(f"Mail in cache (UID {cached[0]})", "GET", f"/messages/INBOX/{cached[0]}", summary=lambda d: f"aperta: {d['subject'][:40]!r}")
if missing:
    show(f"Mail non in cache (UID {missing[0]})", "GET", f"/messages/INBOX/{missing[0]}")
show("Ricerca locale \"camera\"", "GET", "/search?q=camera&limit=1", summary=lambda d: f"{d['total']} risultati")
show("Ricerca sul server", "GET", "/search/server?q=camera")
if cached:
    show("Segna come letto", "PUT", f"/messages/INBOX/{cached[0]}/seen", {"seen": True})
show("Invio (server SMTP finto)", "POST", "/send", {"to": ["prova@example.com"], "cc": [], "subject": "prova", "body": "x", "references": []})
PY
echo
echo "Righe del core sullo stato della connessione:"
grep -A1 "PostinoVip.Cache" "$LOG" | grep -E "raggiungibile" | sed 's/^ */  /' || echo "  (nessuna)"
