#!/usr/bin/env bash
# Schermate dell'app con una casella d'esempio (tappa «Aspetto», V0): persone e mail inventate, nessun core, nessuna
# rete, la tua casella e le tue impostazioni non vengono toccate. Serve a confrontare l'aspetto prima e dopo ogni step.
#
# Uso: tools/schermate.sh [cartella]      (predefinita: dist/schermate/<data-ora>)
# Crea 5 PNG (1440×900 a densità 2, l'ultima 640×480): posta chiara, posta scura, nuovo messaggio, calendario,
# finestra piccola. Il testo usa Inter dagli asset dell'app, come l'app su Linux (dalla V1); il carattere che il
# sistema dà per «sans-serif» (fc-match) resta per i testi senza un carattere proprio.
set -euo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
OUT=${1:-$ROOT/dist/schermate/$(date +%Y%m%d-%H%M%S)}
mkdir -p "$OUT"
OUT=$(readlink -f "$OUT")
FLUTTER=$(command -v flutter) || { echo "flutter non trovato nel PATH"; exit 1; }

font() { fc-match -f '%{file}' "sans-serif:$1" 2>/dev/null || true; }
export SCHERMATE_DIR="$OUT"
export SCHERMATE_FONT_REGULAR=$(font regular)
export SCHERMATE_FONT_MEDIUM=$(font medium)
export SCHERMATE_FONT_BOLD=$(font bold)
export FLUTTER_ROOT=$(cd "$(dirname "$(readlink -f "$FLUTTER")")/.." && pwd)
echo "Carattere: Inter (di riserva: $(fc-match -f '%{family}' sans-serif 2>/dev/null || echo 'non trovato'))"

cd "$ROOT/app"
if flutter test test_screenshots/schermate_test.dart --reporter compact > "$OUT.log" 2>&1; then
  rm -f "$OUT.log"
  echo "Fatto: $(ls "$OUT"/*.png | wc -l) schermate in $OUT"
  ls -1 "$OUT" | grep '\.png$'
  if [ -s "$OUT/avvisi.txt" ]; then
    echo "Avvisi (testo che non sta nel suo spazio, o senza carattere):"
    sed 's/^/  /' "$OUT/avvisi.txt"
  else
    echo "Nessun avviso."
    rm -f "$OUT/avvisi.txt"
  fi
else
  echo "Errore: dettagli in $OUT.log"
  tail -20 "$OUT.log"
  exit 1
fi
