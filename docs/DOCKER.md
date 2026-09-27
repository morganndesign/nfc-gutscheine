# Docker

## Images

| Image | Dockerfile | Contents |
|---|---|---|
| `giftcard-pro-api` | `backend/Dockerfile` | PHP 8.4-FPM (Alpine), extensions `pdo_mysql intl gd zip bcmath opcache pcntl redis`, OPcache + JIT, optimized autoloader, non-root `www-data`. Built from the **repository root** as context (it copies `infra/docker/php/*`). |
| `giftcard-pro-web` | `dashboard/Dockerfile` | Next.js standalone server on Node 22 (Alpine), non-root `nextjs`. ~150 MB. |

Both images are multi-stage: build tools and dev dependencies never reach the runtime layer.

The API image serves three roles, selected by `CONTAINER_ROLE`:

| Role | Command | Purpose |
|---|---|---|
| `app` | `php-fpm` | HTTP API. Runs migrations + reference seeders on start (`RUN_MIGRATIONS=true`). |
| `worker` | `php artisan queue:work redis` | E-mails and other queued jobs. |
| `scheduler` | `php artisan schedule:work` | Nightly card expiration (00:15), reminders (09:00), housekeeping. |

The entrypoint (`infra/docker/php/entrypoint.sh`) caches config, routes, views and events on every start.

## Production stack (`docker-compose.yml`)

```
                ┌──────────────── Hetzner host ─────────────────┐
 Internet ──443─▶ caddy ──/api,/sanctum,/up──▶ api (php-fpm)    │
                │   │                          queue, scheduler │
                │   └──────── everything else ─▶ web (Next.js)  │
                │                     mysql 8.4 · redis 7.4     │
                └────────────────────────────────────────────────┘
```

- **Caddy** terminates TLS (automatic Let's Encrypt, HTTP/3), adds HSTS and routes by path. Because the app
  and the API share one origin, Sanctum cookies are first-party and no CORS configuration exists at all.
- **MySQL** runs with `READ-COMMITTED` isolation (short lock times for the row-locking money path) and
  `utf8mb4`.
- **Redis** runs with AOF persistence and `noeviction` (queues and sessions must never be evicted).
- Only Caddy publishes ports.

```bash
docker compose --env-file .env.production up -d
docker compose --env-file .env.production ps
docker compose --env-file .env.production logs -f api queue
```

## Everyday operations

```bash
# artisan inside the running API container
docker compose --env-file .env.production exec api php artisan about
docker compose --env-file .env.production exec api php artisan platform:create-admin ops@example.com

# failed jobs
docker compose --env-file .env.production exec api php artisan queue:failed
docker compose --env-file .env.production exec api php artisan queue:retry all

# database shell
docker compose --env-file .env.production exec mysql mysql -u root -p giftcard_pro

# backup now
docker compose --env-file .env.production --profile backup run --rm backup
```

## Building locally

```bash
docker build -f backend/Dockerfile -t giftcard-pro-api .
docker build -t giftcard-pro-web dashboard
```

## Development services

`docker-compose.dev.yml` only starts MySQL, Redis and Mailpit; the apps run natively for hot reload.
