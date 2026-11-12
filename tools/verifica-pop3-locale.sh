#!/usr/bin/env bash
# Verifica 4.2b (core): operazioni sul computer degli account POP3 (letto, contrassegni, sposta, copia,
# elimina e definitiva, cartelle, bozze, rimozione dal server dopo l'eliminazione da Posta eliminata).
# Tutto in cartelle temporanee, con un server POP3 finto locale: nessun collegamento alla casella vera.
# Esegue le prove della casella locale (Pop3Tests) e quelle attraverso gli endpoint (Pop3EndpointTests),
# poi stampa l'elenco delle prove con l'esito.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
cd "$ROOT/core" || exit 1
OUT=$(mktemp -d -t postinovip-pop3-locale-XXXX)
trap 'rm -rf "$OUT"' EXIT

dotnet test tests/PostinoVip.Core.Tests --filter "FullyQualifiedName~Pop3Tests" --logger "trx;LogFileName=core.trx" \
  --results-directory "$OUT" > "$OUT/core.txt" 2>&1
dotnet test tests/PostinoVip.Api.Tests --filter "FullyQualifiedName~Pop3EndpointTests" --logger "trx;LogFileName=api.trx" \
  --results-directory "$OUT" > "$OUT/api.txt" 2>&1

python3 -I - "$OUT/core.trx" "$OUT/api.trx" <<'PY'
import sys, xml.etree.ElementTree as ET
ns = {"t": "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"}
ok = ko = 0
for path in sys.argv[1:]:
    try:
        root = ET.parse(path).getroot()
    except Exception as e:
        print(f"  ERRORE risultati non leggibili ({path}): {e}"); ko += 1; continue
    for r in sorted(root.iterfind(".//t:UnitTestResult", ns), key=lambda r: r.get("testName")):
        full = r.get("testName"); head, paren, args = full.partition("(")
        name = head.rsplit(".", 1)[-1] + paren + args
        passed = r.get("outcome") == "Passed"
        ok += passed; ko += not passed
        print(f"  {'OK    ' if passed else 'ERRORE'} {name}")
print(f"\nRisultato: {ok} prove riuscite, {ko} non riuscite.")
sys.exit(1 if ko else 0)
PY
