#!/usr/bin/env bash
# Esportazione della versione pubblica di PostinoVip (preparazione alla pubblicazione, P3, 12/11/2026).
#
# Il repository di sviluppo è privato (la sua cronologia contiene dati reali); quello pubblico riceve solo
# esportazioni ripulite, un commit per pubblicazione. Questo script:
#   1. prende i file COMMITTATI di una versione (git archive: niente file locali, dist/, oauth-clients.json,
#      modifiche non salvate);
#   2. toglie i percorsi elencati in tools/esclusi-pubblico.txt;
#   3. li controlla: dati reali (espressioni di tools/dati-privati.txt, file NON versionato), file che non devono
#      mai uscire (.eml, chiavi, oauth-clients.json, appsettings locali, .env), JSON con password/segreti/token
#      non vuoti, file oltre 5 MB. Al primo problema si ferma e non copia niente;
#   4. copia i file nella cartella del repository pubblico (un clone git), togliendo quelli che non esistono più,
#      e mostra cosa cambia;
#   5. solo con --commit, e dopo aver scritto PUBBLICA, crea un commit «PostinoVip <versione>» con l'indirizzo
#      noreply di GitHub come autore. Non fa MAI il push: quello si fa a mano, dopo aver guardato il commit.
#
# Uso: tools/esporta-pubblico.sh <cartella-del-repository-pubblico> [--ref <commit>] [--commit]
#   --ref     versione da esportare (predefinito: HEAD)
#   --commit  crea il commit nel repository pubblico (chiede conferma)
set -euo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
AUTHOR_NAME="Marcello Anderlini"
AUTHOR_EMAIL="dummy1969@users.noreply.github.com"

DEST=; REF=HEAD; DO_COMMIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF=${2:?manca il commit dopo --ref}; shift 2 ;;
    --commit) DO_COMMIT=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) [ -z "$DEST" ] || { echo "Troppi argomenti: $1"; exit 2; }; DEST=$1; shift ;;
  esac
done
[ -n "$DEST" ] || { echo "Uso: tools/esporta-pubblico.sh <cartella-del-repository-pubblico> [--ref <commit>] [--commit]"; exit 2; }

PATTERNS="$ROOT/tools/dati-privati.txt"
[ -s "$PATTERNS" ] && grep -qvE '^\s*(#|$)' "$PATTERNS" \
  || { echo "Manca tools/dati-privati.txt (elenco dei dati reali, non versionato): senza non si esporta."; exit 1; }

DEST=$(mkdir -p "$DEST" && cd "$DEST" && pwd)
case "$DEST/" in "$ROOT/"*) echo "La cartella pubblica non può stare dentro il repository privato: $DEST"; exit 1 ;; esac
git -C "$DEST" rev-parse --is-inside-work-tree >/dev/null 2>&1 && [ "$(git -C "$DEST" rev-parse --show-toplevel)" = "$DEST" ] \
  || { echo "$DEST non è un repository git (clona quello pubblico, o per una prova: git init \"$DEST\")."; exit 1; }
[ -z "$(git -C "$DEST" status --porcelain)" ] || { echo "Il repository pubblico ha modifiche non salvate: sistemale prima."; exit 1; }
# La conferma (PUBBLICA) si scrive in un terminale: con «!» di Claude Code o in una pipe non c'è chi risponde.
[ "$DO_COMMIT" -ne 1 ] || [ -t 0 ] \
  || { echo "--commit chiede di scrivere PUBBLICA: lancia lo script in un terminale (non con «!» da Claude Code). Nessuna modifica."; exit 1; }

SHA=$(git -C "$ROOT" rev-parse --verify "$REF^{commit}")
VERSION=$(git -C "$ROOT" show "$SHA:core/Directory.Build.props" | sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p')
[ -n "$VERSION" ] || { echo "Versione non trovata in core/Directory.Build.props di $REF"; exit 1; }
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || [ "$REF" != HEAD ] \
  || echo "Nota: ci sono modifiche non committate nel repository privato; si esporta solo ciò che è committato."

WORK=$(mktemp -d -t postinovip-esporta-XXXX)
trap 'rm -rf "$WORK"' EXIT
# Nessuna uscita in silenzio: un comando fallito dice dove (riga), anche se è un errore dello script.
COPIED=0
# Riporta il clone pubblico com'era (ultimo commit, o vuoto se non ne ha ancora): dopo una prova senza --commit,
# un annullamento o un errore non resta mai «sporco» (e il giro dopo non viene rifiutato).
restore() {
  if git -C "$DEST" rev-parse -q --verify HEAD >/dev/null; then
    git -C "$DEST" reset -q --hard HEAD || true
    git -C "$DEST" clean -fdq || true
  else
    git -C "$DEST" rm -rqf --cached . >/dev/null 2>&1 || true
    find "$DEST" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + || true
  fi
}
on_error() {
  if [ "$COPIED" -eq 1 ]; then
    restore
    echo "Errore inatteso alla riga $1 di tools/esporta-pubblico.sh: nessun commit, clone pubblico riportato com'era." >&2
  else
    echo "Errore inatteso alla riga $1 di tools/esporta-pubblico.sh: niente è stato copiato né pubblicato." >&2
  fi
}
trap 'on_error $LINENO' ERR
mkdir "$WORK/tree"
git -C "$ROOT" archive --format=tar "$SHA" | tar -x -C "$WORK/tree"

# Percorsi da non pubblicare (versionato, può essere vuoto): uno per riga, relativi alla radice.
EXCLUDE="$WORK/tree/tools/esclusi-pubblico.txt"
if [ -f "$EXCLUDE" ]; then
  # «|| true»: un elenco di soli commenti fa uscire grep con 1, che con pipefail fermava lo script in silenzio.
  { grep -vE '^\s*(#|$)' "$EXCLUDE" || true; } | while IFS= read -r p; do
    case "$p" in /*|*..*) echo "Percorso non valido in esclusi-pubblico.txt: $p"; exit 1 ;; esac
    rm -rf "${WORK:?}/tree/$p"
  done
fi

echo "Versione $VERSION (commit ${SHA:0:7}): controllo dei file…"
# «|| exit 1»: problemi trovati = uscita voluta, non un «errore inatteso».
python3 -I - "$WORK/tree" "$PATTERNS" <<'EOF' || exit 1
import json, os, re, sys
root, patterns_file = sys.argv[1], sys.argv[2]
patterns = [l.strip() for l in open(patterns_file, encoding="utf-8") if l.strip() and not l.lstrip().startswith("#")]
forbidden = re.compile("|".join(f"(?:{p})" for p in patterns).encode(), re.IGNORECASE)
bad_names = re.compile(r"(\.eml|\.pem|\.key|\.pfx|\.p12|\.jks|\.keystore|\.env)$|(^|/)(oauth-clients\.json|secrets\.json"
                       r"|appsettings\.(Development|Local)\.json|[^/]*\.local\.json|dati-privati\.txt)$", re.IGNORECASE)
secret_key = re.compile(r"(password|secret|token|apikey|api_key)", re.IGNORECASE)
problems, files, size = [], 0, 0

def secrets_in(obj, path=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{path}.{k}" if path else k
            if isinstance(v, str) and v.strip() and secret_key.search(k):
                yield p
            else:
                yield from secrets_in(v, p)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from secrets_in(v, f"{path}[{i}]")

for dirpath, _, names in os.walk(root):
    for name in names:
        full = os.path.join(dirpath, name)
        rel = os.path.relpath(full, root)
        files += 1
        n = os.path.getsize(full); size += n
        if bad_names.search(rel):
            problems.append(f"{rel}: file che non deve essere pubblicato")
        if n > 5 * 1024 * 1024:
            problems.append(f"{rel}: oltre 5 MB ({n // 1024 // 1024} MB)")
        data = open(full, "rb").read()
        for m in forbidden.finditer(data):
            line = data.count(b"\n", 0, m.start()) + 1
            problems.append(f"{rel}:{line}: dato reale (da dati-privati.txt; il valore non si stampa)")
            break  # un file basta segnalarlo una volta; il valore trovato non si stampa
        if rel.lower().endswith(".json"):
            try:
                for key in secrets_in(json.loads(data.decode("utf-8-sig"))):
                    problems.append(f"{rel}: «{key}» non vuoto")
            except ValueError:
                pass  # non è JSON valido (es. un modello): non è un segreto di configurazione

print(f"  {files} file, {size / 1024 / 1024:.1f} MB")
if problems:
    print("FERMATO: problemi trovati, niente è stato copiato:")
    for p in problems: print("  - " + p)
    sys.exit(1)
print("  nessun dato reale né file vietato")
EOF

# Copia: via tutto tranne .git, poi i file nuovi (così spariscono anche quelli tolti nel privato).
COPIED=1
find "$DEST" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$WORK/tree/." "$DEST/"
git -C "$DEST" add -A
CHANGES=$(git -C "$DEST" diff --cached --name-status | awk '{print $1}' | sort | uniq -c | awk '{printf "%s %s  ", $1, $2}')
if [ -z "$(git -C "$DEST" diff --cached --name-only)" ]; then
  echo "Nessuna differenza rispetto all'ultima esportazione."
  exit 0
fi
echo "Differenze rispetto all'ultima esportazione (A aggiunti, M modificati, D tolti): $CHANGES"
git -C "$DEST" diff --cached --stat | tail -1

if [ "$DO_COMMIT" -ne 1 ]; then
  restore
  echo "Prova senza --commit: nessun commit, clone riportato com'era."
  exit 0
fi
if ! read -r -p "Scrivi PUBBLICA per creare il commit «PostinoVip $VERSION» in $DEST: " ANSWER; then
  restore
  echo; echo "Nessuna risposta: nessun commit, clone riportato com'era."
  exit 1
fi
if [ "$ANSWER" != PUBBLICA ]; then
  restore
  echo "Annullato: nessun commit, clone riportato com'era."
  exit 1
fi
git -C "$DEST" -c user.name="$AUTHOR_NAME" -c user.email="$AUTHOR_EMAIL" \
  commit -q --author="$AUTHOR_NAME <$AUTHOR_EMAIL>" -m "PostinoVip $VERSION" -m "Esportazione della versione $VERSION."
echo "Commit creato: $(git -C "$DEST" log --oneline -1)"
echo "Niente push: dopo averlo guardato, git -C \"$DEST\" push"
