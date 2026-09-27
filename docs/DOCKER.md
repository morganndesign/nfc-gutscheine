# Docker

Production runs on **Coolify**, which builds every image from this repository on the server
([docs/DEPLOYMENT.md](DEPLOYMENT.md)). There is no registry and no pre-built image.

## Images (all built from source by `docker-compose.coolify.yml`)

| Service(s) | Dockerfile | Contents |
|---|---|---|
| `api`, `worker`, `scheduler` | `backend/Dockerfile` (target `production`, context = repository root) | PHP 8.4-FPM (Alpine), extensions `pdo_mysql intl gd zip bcmath opcache pcntl redis`, OPcache + JIT, optimized autoloader, non-root `www-data`, `infra/docker/php/*` (php.ini, www.conf, entrypoint). |
| `web` | `dashboard/Dockerfile` | Next.js standalone server on Node 22 (Alpine), non-root `nextjs`. |
| `gateway` | `infra/docker/gateway/Dockerfile` | Caddy 2 with `infra/docker/gateway/Caddyfile` (validated at build time). |
| `mysql`, `backup` | image `mysql:8.4` | — |
| `redis` | image `redis:7.4-alpine` | — |

The Laravel image is built from `backend/Dockerfile` for three services, selected by `CONTAINER_ROLE`
(`infra/docker/php/entrypoint.sh`):

| Role | Command | Purpose |
|---|---|---|
| `app` | `php-fpm` | HTTP API, reached by the gateway over FastCGI (:9000). |
| `worker` | `php artisan queue:work redis …` | E-mails, notifications, other queued jobs. |
| `scheduler` | `php artisan schedule:work` | Nightly card expiry, reminders, housekeeping. |

There is no `depends_on` and no one-shot service; on start every Laravel container generates the APP_KEY once
(first deploy, unless set), waits for MySQL and Redis, runs `migrate --force --isolated` (one container at a time)
and waits until no migration is pending; `app` then seeds reference data. Then config, routes, views and events
are cached and the process starts. The entrypoint derives `APP_URL`, `FRONTEND_URL`, `CARD_BASE_URL`, `SESSION_DOMAIN`
and `SANCTUM_STATEFUL_DOMAINS` from the gateway domain Coolify assigns.

## Stack

```
Coolify proxy (TLS) ──▶ gateway :80 ──/api,/sanctum,/up,/reset-password──FastCGI──▶ api :9000
                                    └──everything else─────────────────HTTP─────▶ web :3000
             worker · scheduler · mysql 8.4 · redis 7.4 · backup
```

- The dashboard and the API share one origin: Sanctum cookies are first-party, no CORS configuration.
- **MySQL** runs with `READ-COMMITTED` isolation (short lock times for the row-locking money path) and `utf8mb4`.
- **Redis** runs with a password, AOF persistence and `noeviction` (queues and sessions must never be evicted).
- No service publishes a host port; Coolify's proxy reaches the gateway on the internal network.

## Operations

In Coolify: resource → *Terminal* → choose the container. Examples in **api**:

```bash
php artisan about
php artisan platform:create-admin ops@example.com
php artisan queue:failed && php artisan queue:retry all
php artisan migrate:status
```

Database shell and backups: container **backup** (see [DEPLOYMENT.md → Backups](DEPLOYMENT.md#backups)).

## Building locally (optional)

```bash
docker compose -f docker-compose.coolify.yml build            # exactly what Coolify builds
docker build -f backend/Dockerfile --target production -t giftcard-pro-api .
docker build -t giftcard-pro-web dashboard
```

## Development services

`docker-compose.dev.yml` only starts MySQL, Redis and Mailpit; the apps run natively for hot reload.
