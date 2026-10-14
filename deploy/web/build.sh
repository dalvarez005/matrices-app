#!/usr/bin/env bash
# Arma la carpeta del sitio: landing en / y la app de Flutter en /app/.
#
#   deploy/web/build.sh [carpeta-destino]   (por defecto build/site)
#
# Extra: API_BASE_URL=local para probar contra la API de esta PC.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/build/site}"
DEFINES=()
[[ -n "${API_BASE_URL:-}" ]] && DEFINES=(--dart-define=API_BASE_URL="$API_BASE_URL")

(cd "$ROOT" && flutter build web --release --base-href /app/ --no-wasm-dry-run "${DEFINES[@]}")
mkdir -p "$OUT"
rsync -a --delete --exclude app "$ROOT/landing/" "$OUT/"
rsync -a --delete "$ROOT/build/web/" "$OUT/app/"
echo "Sitio listo en $OUT"
