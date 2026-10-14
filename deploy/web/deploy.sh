#!/usr/bin/env bash
# Compila landing + app web, las copia a la Orange Pi y reinicia nginx allí
# (la imagen se construye en el servidor: solo copia archivos).
#
#   deploy/web/deploy.sh [usuario@servidor]
set -euo pipefail

TARGET="${1:-orangepi@192.168.1.77}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "==> Compilando"
"$ROOT/deploy/web/build.sh" "$ROOT/build/site"

echo "==> Copiando a $TARGET:~/matrices-web"
ssh "$TARGET" 'mkdir -p ~/matrices-web/html'
rsync -az "$ROOT/deploy/web/Dockerfile" "$ROOT/deploy/web/nginx.conf" "$ROOT/deploy/web/compose.yaml" "$TARGET:matrices-web/"
rsync -az --delete "$ROOT/build/site/" "$TARGET:matrices-web/html/"

echo "==> Reiniciando"
ssh "$TARGET" 'cd ~/matrices-web && docker compose up -d --build --remove-orphans && docker image prune -f >/dev/null && docker compose ps'
