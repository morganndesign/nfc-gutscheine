# Deployment (Coolify)

GiftCard Pro runs in production as **one Coolify resource** built from this repository with
[`docker-compose.coolify.yml`](../docker-compose.coolify.yml). Coolify clones the repository, builds every image on
your server, starts the stack and gives it HTTPS. There is no container registry, no pre-built image and no
GitHub Actions step involved.

## Architecture

```
Internet ──HTTPS──▶ Coolify proxy (TLS certificate for your domain)
                      │
                      ▼ HTTP, internal network
                    gateway :80  (Caddy, infra/docker/gateway)
                      ├─ /api/*  /sanctum/*  /up  /reset-password/*  ──FastCGI──▶ api :9000   (Laravel, php-fpm)
                      └─ everything else  ──────────────────────────────HTTP────▶ web :3000   (Next.js dashboard)

  migrate   one-shot on every deploy: APP_KEY (first deploy), migrations, reference data → exits
  worker    queue:work (e-mails, notifications)        ┐ start only after migrate
  scheduler schedule:work (nightly expiry, reminders…)  ┘ finished successfully
  mysql     MySQL 8.4            volume mysql-data
  redis     Redis 7.4 (AOF)      volume redis-data     sessions, cache, locks, queues
  backup    daily mysqldump      volume mysql-backups  (kept 14 days)
```

| Service | Built from | Public | Health check | Restart | Volume |
|---|---|---|---|---|---|
| `gateway` | `infra/docker/gateway/` (Caddy) | **yes** — the only service with a domain | `GET /gateway-health` | unless-stopped | — |
| `migrate` | `backend/Dockerfile` | no | none (one-shot, `exclude_from_hc`) | no | `laravel-storage` |
| `api` | `backend/Dockerfile` | no (via gateway) | php-fpm ping | unless-stopped | `laravel-storage` |
| `worker` | `backend/Dockerfile` | no | process check | unless-stopped | `laravel-storage` |
| `scheduler` | `backend/Dockerfile` | no | process check | unless-stopped | `laravel-storage` |
| `web` | `dashboard/Dockerfile` | no (via gateway) | `GET /login` | unless-stopped | — |
| `mysql` | image `mysql:8.4` | no | `mysqladmin ping` | unless-stopped | `mysql-data` |
| `redis` | image `redis:7.4-alpine` | no | `redis-cli ping` | unless-stopped | `redis-data` |
| `backup` | image `mysql:8.4` | no | database reachable | unless-stopped | `mysql-backups` |

Why a gateway: the product is **one origin** — the dashboard, the API, the Sanctum cookies and the card links
(`https://<domain>/c/<token>`) share one domain. The gateway does this path routing inside the stack, so Coolify only
has to route one domain to one container, and nothing depends on proxy-specific path rules.

Start order on every deploy: `mysql` + `redis` healthy → `migrate` runs and exits 0 → `api`, `worker`, `scheduler`
→ `web` → `gateway`. If migrations fail, nothing new starts and the deployment is marked failed.

## What you need

- A server with **Coolify** installed (Ubuntu 24.04, ≥ 2 vCPU / 4 GB RAM; Hetzner CX32/CPX31 in Falkenstein or
  Nürnberg for EU data residency). Coolify install: `curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash`.
- The domain, e.g. `app.giftcardpro.at`, with an **A record** (and AAAA if IPv6) pointing at that server.
- This repository on GitHub (private is fine).
- SMTP credentials of an e-mail service (Postmark, Mailgun, Brevo, …) — invitations and password links need it.

## First deployment — step by step

1. **DNS.** Create `A  app  →  <server IPv4>` (and `AAAA` for IPv6). Wait until `dig +short app.giftcardpro.at`
   returns the IP. Coolify can only get the certificate after that.
2. **Connect GitHub** (once per Coolify): *Sources* → *+ Add* → *GitHub App* → follow the wizard, install the app
   on the repository.
3. **Create the resource:** *Projects* → your project → *+ New* → *Private Repository (with GitHub App)* → choose
   the repository and the branch (`main`).
   - **Build Pack:** `Docker Compose`
   - **Base Directory:** `/`
   - **Docker Compose Location:** `/docker-compose.coolify.yml`
   - *Continue*. Coolify reads the file and lists the services.
4. **Domain:** in the resource's *General* page, *Domains for gateway* → `https://app.giftcardpro.at`.
   Leave all other services without a domain. (Coolify routes it to the gateway's port 80.)
5. **Environment Variables** (resource → *Environment Variables* → *Developer view*):
   - check that `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT` and `SERVICE_PASSWORD_REDIS` have values
     (Coolify generates them) and that `SERVICE_URL_GATEWAY` shows `https://app.giftcardpro.at`;
   - add your e-mail settings from [`.env.production.example`](../.env.production.example):
     `MAIL_MAILER=smtp`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_SCHEME`, `MAIL_USERNAME`, `MAIL_PASSWORD`
     (optional: `MAIL_FROM_ADDRESS`, `OPS_ALERT_EMAIL`). Everything else has production defaults.
6. **Deploy.** The first build takes 5–10 minutes (PHP extensions, Composer, Next.js). Follow the log; at the end
   all services except `migrate` are *healthy* and `migrate` shows *exited (0)*.
7. **First administrator:** resource → *Terminal* → container **api** →
   ```bash
   php artisan platform:create-admin you@giftcardpro.at --name="Your Name"
   ```
   (asks for a password, min. 12 characters, upper/lower case and a digit).
8. **Check:**
   - `https://app.giftcardpro.at/up` → green page ("Application up"; checks database and cache)
   - `https://app.giftcardpro.at/api/v1/app/config?platform=android&version=1.4.2` → JSON
   - `https://app.giftcardpro.at` → sign-in page; sign in, onboard a test restaurant, confirm the welcome e-mail arrives.
9. **Back up the APP_KEY** (generated on the first deploy): *Terminal* → container **api** →
   `cat storage/app/.app-key`. Store it in your password manager, and ideally paste it as `APP_KEY` into the
   Environment Variables (then the key no longer depends on the volume). Never change it on a running system.
10. **Automatic deploys:** resource → *Advanced* → *Auto Deploy* on (default with the GitHub App). Every push to
    `main` builds and deploys; migrations run automatically.

Nothing in the repository has to be edited for any of these steps.

## Updates

Push to `main` (or press *Redeploy*). Coolify builds the new images, then replaces the containers; `migrate` runs
the new migrations before the new `api`/`worker`/`scheduler` start. Expect a few seconds of interruption while
containers are replaced. Migrations are written to be backwards compatible with the previous release
(expand → migrate → contract).

**Rollback:** resource → *Deployments* → pick an earlier deployment → *Redeploy*. The database is not rolled back:
migrations only go forward; restore a backup only for real data loss.

## Backups

The `backup` service writes `giftcard_pro_<UTC timestamp>.sql.gz` into the volume `mysql-backups` every day at
`BACKUP_TIME` (UTC, default 01:30) and deletes dumps older than `BACKUP_KEEP_DAYS` (default 14).

- **Off-site copy (required for real data):** the volume lives on the same disk as the database. On the server,
  find it with `docker volume ls | grep mysql-backups` and sync its `_data` directory off-site, e.g. a root cron job
  `rclone sync /var/lib/docker/volumes/<name>/_data storagebox:giftcard-backups`. Also enable Hetzner server backups.
- **Backup now:** *Terminal* → container **backup** →
  `mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --no-tablespaces "$MYSQL_DATABASE" | gzip > /backups/manual_$(date -u +%Y%m%dT%H%M%SZ).sql.gz`
- **List:** `ls -lh /backups` in the backup container.

**Restore** (replaces all data — take a fresh dump first):
1. *Terminal* → container **api** → `php artisan down` (the dashboard and app show maintenance).
2. *Terminal* → container **backup** →
   `gunzip -c /backups/<file>.sql.gz | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"`
3. Resource → *Redeploy* (runs migrations newer than the dump, brings the app back up).

Test a restore once a month into a scratch database: in the backup container
`mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE restore_test"`, restore into `restore_test`,
check it, `DROP DATABASE restore_test`.

## Operations

| Task | Where |
|---|---|
| Logs of a service | resource → *Logs* (all services log to stdout/stderr; Laravel uses `LOG_CHANNEL=stderr`) |
| Artisan command | *Terminal* → **api** → `php artisan …` (e.g. `migrate:status`, `schedule:list`, `queue:failed`) |
| NFC 424 keys | *Terminal* → **api** → `php artisan giftcard:nfc-keys` → add both to the Environment Variables → *Redeploy* |
| Change a setting | *Environment Variables* → *Redeploy* (configuration is cached at container start) |
| Waiter app links | set `WAITER_ANDROID_PACKAGE`, `WAITER_ANDROID_CERT_SHA256`, `WAITER_IOS_APP_IDS` → *Redeploy*; check `/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association` |
| Monitoring | an uptime check on `https://<domain>/up` (Better Stack, UptimeRobot…); `OPS_ALERT_EMAIL` gets a mail when a queue exceeds 500 jobs |

Nightly jobs (scheduler, times in `SCHEDULE_TIMEZONE`, default Europe/Vienna): 00:15 `giftcards:expire`,
03:30 `queue:prune-failed`, 10:00 `giftcards:notify-expiring`, every 15 min `auth:clear-resets`, every 5 min
`queue:monitor`. Check with `php artisan schedule:list` in the api container.

## Staging

A second Coolify resource from the same repository and the same compose file, with its own domain (e.g.
`https://staging.giftcardpro.at`) and `APP_ENV=staging` in its Environment Variables (branch `main` or a `staging`
branch). It has its own database, Redis and volumes. Staging is held to the same rules as production (https URLs).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `migrate` fails with "No public URL" | The gateway has no domain. Step 4. |
| `migrate` fails with "app.url must be the https URL …" | The gateway domain is `http://…` (e.g. Coolify's generated sslip.io domain). Use an `https://` domain; for a quick test without your own domain, `https://<anything>.<server-ip>.sslip.io` works. |
| `migrate` fails with "DB_PASSWORD is empty" | Coolify did not generate `SERVICE_PASSWORD_MYSQL` (older Coolify versions). Set `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT` and `SERVICE_PASSWORD_REDIS` yourself (long random values) **before** the first deploy, then *Redeploy*. |
| `migrate` fails with "Access denied for user" after changing a password | The MySQL volume keeps the password of its first start. Put the old value back, or (only without data) delete the `mysql-data` volume. |
| Certificate not issued / "not secure" | DNS does not point at the server yet, or ports 80/443 are closed. |
| 419 / sign-in loops in the dashboard | The browser URL differs from the gateway domain (cookies are bound to it). Use exactly the configured domain. |
| Build fails at `pecl install redis`, `composer install` or `npm ci` | Temporary outage of pecl.php.net, GitHub or npm. *Redeploy*. |

## Scaling out

| Need | Step |
|---|---|
| More web traffic | Raise `pm.max_children` in `infra/docker/php/www.conf`, give the server more CPU; the app is stateless (sessions, cache, locks in Redis). |
| Database | Move MySQL to a managed database: set `DB_HOST`, `DB_PASSWORD` etc. and remove the `mysql`/`backup` services. |
| Isolation for enterprise customers | Deploy the same repository as its own Coolify resource per customer (single-tenant) — no code changes. |
