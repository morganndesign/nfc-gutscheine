#!/usr/bin/env bash
# Zero-downtime-ish deploy on the Hetzner host. Called by GitHub Actions over SSH:
#   IMAGE_TAG=<sha> ./infra/scripts/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

export IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG required}"

echo "→ Pulling images ${IMAGE_TAG}"
docker compose --env-file .env.production pull api queue scheduler web

echo "→ Starting API (runs migrations)"
docker compose --env-file .env.production up -d --no-deps api
docker compose --env-file .env.production exec -T api php artisan migrate:status >/dev/null

echo "→ Rolling workers and web"
docker compose --env-file .env.production up -d --no-deps queue scheduler web caddy
docker compose --env-file .env.production exec -T api php artisan queue:restart

echo "→ Health check"
for i in $(seq 1 30); do
  if curl -fsS "https://${APP_DOMAIN}/up" >/dev/null; then
    echo "✓ Deployed ${IMAGE_TAG}"
    docker image prune -f >/dev/null
    exit 0
  fi
  sleep 2
done
echo "✗ Health check failed" >&2
exit 1
