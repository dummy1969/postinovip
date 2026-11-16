#!/usr/bin/env bash
# Verifica M1 (macOS, prima build di sviluppo). Da eseguire SUL MAC, dalla cartella del repository:
#   tools/verifica-macos.sh
# Nessun collegamento alla casella: controlla gli strumenti, compila e prova il core e l'app, crea l'app di
# sviluppo (PostinoVip.app) e controlla che l'app trovi il core compilato. Scritto per la bash 3.2 di macOS.
# Riepilogo finale in $OUT/riepilogo.txt; i log completi di ogni passo nella stessa cartella.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/dist/verifica-macos/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
ok=0; ko=0
riga() { echo "$1" | tee -a "$OUT/riepilogo.txt"; }
passo() { # passo <nome> <file di log> <comando...>
  local nome=$1 log=$2; shift 2
  printf '… %s\n' "$nome"
  if "$@" > "$OUT/$log" 2>&1; then riga "  OK      $nome"; ok=$((ok + 1)); return 0
  else riga "  ERRORE  $nome (log: $OUT/$log, ultime righe sotto)"; tail -n 15 "$OUT/$log" | sed 's/^/          /'
    ko=$((ko + 1)); return 1; fi
}

if [ "$(uname -s)" != "Darwin" ]; then echo "Questo script va eseguito su macOS."; exit 1; fi

riga "== Ambiente =="
riga "  macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), processore $(uname -m)"
for cmd in xcodebuild dotnet flutter; do
  if ! command -v "$cmd" > /dev/null; then riga "  ERRORE  manca il comando '$cmd'"; ko=$((ko + 1)); fi
done
if [ "$ko" -gt 0 ]; then riga "Installare prima gli strumenti mancanti."; exit 1; fi
riga "  $(xcodebuild -version | tr '\n' ' ')"
riga "  .NET SDK $(dotnet --version)"
riga "  $(flutter --version 2>/dev/null | head -1)"
flutter doctor -v > "$OUT/flutter-doctor.txt" 2>&1
grep -E '^\[(✓|!|✗|☠)\]' "$OUT/flutter-doctor.txt" | sed 's/^/  /' | tee -a "$OUT/riepilogo.txt"

riga ""; riga "== Core (C#) =="
cd "$ROOT/core" || exit 1
passo "dotnet build" core-build.txt dotnet build
passo "dotnet test" core-test.txt dotnet test
grep -E '^(Superato|Non superato|Passed|Failed)!' "$OUT/core-test.txt" | sed 's/^/          /' | tee -a "$OUT/riepilogo.txt"
CORE="$ROOT/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api"
if [ -x "$CORE" ]; then riga "  OK      eseguibile del core: $CORE"; ok=$((ok + 1))
else riga "  ERRORE  eseguibile del core non trovato: $CORE"; ko=$((ko + 1)); fi

riga ""; riga "== App (Flutter) =="
cd "$ROOT/app" || exit 1
passo "flutter pub get" app-pubget.txt flutter pub get
if ! git -C "$ROOT" diff --quiet -- app/pubspec.lock; then
  riga "  AVVISO  pub get ha cambiato app/pubspec.lock (non va committato: dirlo a Claude)"
fi
passo "flutter analyze" app-analyze.txt flutter analyze
passo "flutter test" app-test.txt flutter test
tail -n 1 "$OUT/app-test.txt" | sed 's/^/          /' | tee -a "$OUT/riepilogo.txt"
passo "flutter build macos --debug" app-build.txt flutter build macos --debug
APP="$ROOT/app/build/macos/Build/Products/Debug/PostinoVip.app"
EXE="$APP/Contents/MacOS/PostinoVip"
if [ -x "$EXE" ]; then
  riga "  OK      app di sviluppo: $APP"; ok=$((ok + 1))
  # Stessa ricerca di CoreLauncher.findExecutable su macOS: si risale dall'eseguibile fino a core/.
  dir=$(dirname "$EXE"); found=""
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    if [ -x "$dir/core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api" ]; then found="$dir"; break; fi
    dir=$(dirname "$dir")
  done
  if [ -n "$found" ]; then riga "  OK      l'app troverà il core risalendo fino a $found"; ok=$((ok + 1))
  else riga "  ERRORE  risalendo dall'app non si trova core/"; ko=$((ko + 1)); fi
  sb=$(codesign -d --entitlements - "$APP" 2>/dev/null | grep -c app-sandbox || true)
  if [ "$sb" = "0" ]; then riga "  OK      sandbox spenta (scelta 1a)"; ok=$((ok + 1))
  else riga "  ERRORE  l'app ha ancora la sandbox"; ko=$((ko + 1)); fi
else
  riga "  ERRORE  app di sviluppo non trovata: $EXE"; ko=$((ko + 1))
fi

riga ""
riga "Risultato: $ok OK, $ko errori. Riepilogo: $OUT/riepilogo.txt"
if [ "$ko" -eq 0 ]; then
  riga "Ora avviare l'app:  cd app && flutter run -d macos"
fi
[ "$ko" -eq 0 ]
