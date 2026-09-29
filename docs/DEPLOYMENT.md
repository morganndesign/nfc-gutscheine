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
                      ├─ /api/*  /sanctum/*  /up  ──FastCGI──▶ api :9000   (Laravel, php-fpm)
                      └─ everything else  ─────────HTTP────▶ web :3000   (Next.js dashboard and web till)

  worker    queue:work (every e-mail is sent from the queue)
  scheduler schedule:work (nightly expiry, integrity check, reminders…)
  mysql     MySQL 8.4            volume mysql-data
  redis     Redis 7.4 (AOF)      volume redis-data     sessions, cache, locks, queues
  backup    daily mysqldump      volume mysql-backups  (kept 14 days)
```

| Service | Built from | Public | Health check | Restart | Volume |
|---|---|---|---|---|---|
| `gateway` | `infra/docker/gateway/` (Caddy) | **yes** — the only service with a domain | `GET /gateway-health` | unless-stopped | — |
| `api` | `backend/Dockerfile` | no (via gateway) | php-fpm ping | unless-stopped | `laravel-storage` |
| `worker` | `backend/Dockerfile` | no | process check | unless-stopped | `laravel-storage` |
| `scheduler` | `backend/Dockerfile` | no | process check | unless-stopped | `laravel-storage` |
| `web` | `dashboard/Dockerfile` | no (via gateway) | `GET /login` | unless-stopped | — |
| `mysql` | image `mysql:8.4` | no | `mysqladmin ping` | unless-stopped | `mysql-data` |
| `redis` | image `redis:7.4-alpine` | no | `redis-cli ping` | unless-stopped | `redis-data` |
| `backup` | image `mysql:8.4` | no | — | unless-stopped | `mysql-backups` |

Why a gateway: the product is **one origin** — the dashboard, the web till, the API and the Sanctum cookies share
one domain. The gateway does this path routing inside the stack, so Coolify only
has to route one domain to one container, and nothing depends on proxy-specific path rules.

Start order: the compose file has **no `depends_on`** — Coolify starts all eight containers at once. The order is
enforced inside the Laravel containers (`infra/docker/php/entrypoint.sh`): wait until MySQL and Redis accept
connections (up to 15 minutes on fresh volumes) → run the migrations (a Redis lock lets exactly one container
migrate, the others wait until nothing is pending) → `api` seeds reference data (roles and permissions, e-mail
templates, system settings) → start. Until then the gateway
answers 502 for the API. A failing migration stops the container with the error in its log (resource → *Logs*).

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
   all eight services are *healthy* (on the first deploy the Laravel services need 1–3 minutes: MySQL initialises, then the migrations run).
7. **First administrator:** resource → *Terminal* → container **api** →
   ```bash
   php artisan platform:create-admin you@giftcardpro.at --name="Your Name"
   ```
   (asks for a password, min. 12 characters, upper/lower case and a digit).
8. **Check:**
   - `https://app.giftcardpro.at/up` → green page ("Application up"; checks database and cache)
   - `https://app.giftcardpro.at/api/v1/app/config?platform=android&version=2.0.0` → JSON
   - `https://app.giftcardpro.at` → sign-in page; sign in, onboard a test restaurant, confirm the welcome e-mail arrives.
9. **Back up the APP_KEY** (generated on the first deploy): *Terminal* → container **api** →
   `cat storage/app/.app-key`. Store it in your password manager, and ideally paste it as `APP_KEY` into the
   Environment Variables (then the key no longer depends on the volume). Never change it on a running system.
10. **Automatic deploys:** resource → *Advanced* → *Auto Deploy* on (default with the GitHub App). Every push to
    `main` builds and deploys; migrations run automatically.

Nothing in the repository has to be edited for any of these steps, and no `.env` file is needed: all configuration
comes from the environment variables of the Coolify resource.

## Updates

Push to `main` (or press *Redeploy*). Coolify builds the new images, then replaces the containers; the first new
Laravel container runs pending migrations, and `api`/`worker`/`scheduler` only start serving after that. Expect a
few seconds of interruption while containers are replaced.

**Rebuilding the database.** The schema is the set of migrations `2026_01_01_000001` … `000007`
([DATABASE.md](DATABASE.md#installing-the-schema)). A database that was created from an earlier schema is rebuilt
once, which deletes all its data: *Terminal* → container **api** →

```bash
php artisan migrate:fresh --seed --force
php artisan platform:create-admin you@giftcardpro.at --name="Your Name"
php artisan giftcard:verify-chains
```

**Rollback:** resource → *Deployments* → pick an earlier deployment → *Redeploy*. The database is not rolled back;
restore a backup only for real data loss.

## Backups

The `backup` service writes, every day at `BACKUP_TIME` (UTC, default 01:30), into the volume `mysql-backups`:

- `giftcard_pro_<UTC timestamp>.sql.gz` — a consistent dump (`--single-transaction`, with the append-only
  triggers). It only counts when `gzip -t` passes and the dump ends with `Dump completed`;
- `keystore_<UTC timestamp>.json` — a copy of the **card keystore** (still encrypted with `CRYPTO_KEYSTORE_KEY`).
  Without the keystore no card ever issued can be verified again: it is as important as the database;
- `last_success` — what the backup check reads.

Files older than `BACKUP_KEEP_DAYS` (default 14) are deleted.

**Off-site copy (required before real money):** the `offsite` service copies the backup directory, one hour after
the backup (`OFFSITE_TIME`, default 02:30 UTC), to an SFTP server — e.g. a Hetzner Storage Box (a few euros a
month) — through an rclone *crypt* remote: contents and file names are encrypted before they leave the server, and
remote copies older than `OFFSITE_KEEP_DAYS` (default 60) are deleted. Set in Coolify:

| Variable | Value |
|---|---|
| `OFFSITE_SFTP_HOST`, `OFFSITE_SFTP_USER`, `OFFSITE_SFTP_PORT` (23 for a Storage Box) | The SFTP account |
| `OFFSITE_SFTP_PASS_OBSCURED` | Its password, obscured: `docker run --rm rclone/rclone:1.68 obscure '<password>'` |
| `OFFSITE_CRYPT_PASSWORD_OBSCURED`, `OFFSITE_CRYPT_SALT_OBSCURED` | Two long random secrets (e.g. `openssl rand -base64 32`), each obscured the same way |

Keep the two crypt secrets (not obscured) in the password manager **and offline**, with `CRYPTO_KEYSTORE_KEY`:
without them the off-site copies cannot be read. Also enable Hetzner server backups (snapshots of the whole server).

**Backup check:** `ops:check-backups` runs every hour in the scheduler (which sees the backup volume read-only) and
e-mails `OPS_ALERT_EMAIL` (at most twice a day) when the last dump is older than 26 hours or suspiciously small,
when the keystore has no copy, when the off-site copy is older than 26 hours — or when no off-site target is
configured at all.

- **Backup now:** *Terminal* → container **backup** →
  `mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --no-tablespaces "$MYSQL_DATABASE" | gzip > /backups/manual_$(date -u +%Y%m%dT%H%M%SZ).sql.gz`
- **List:** `ls -lh /backups` in the backup container; `rclone ls secure:` in the offsite container.
- **Fetch from off-site** (the server is gone): on any machine with rclone and the same `RCLONE_CONFIG_*` values,
  `rclone copy secure: ./restore`.

**Restore** (replaces all data — take a fresh dump first):
1. *Terminal* → container **api** → `php artisan down` (the dashboard and app show maintenance). On a new server,
   copy the newest `keystore_*.json` to `storage/app/private/crypto/keystore.json` in the `laravel-storage` volume and
   set the same `CRYPTO_KEYSTORE_KEY` before the first start; `php artisan cards:key-set:verify` must pass.
2. *Terminal* → container **backup** →
   `gunzip -c /backups/<file>.sql.gz | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"`
3. Resource → *Redeploy* (brings the app back up).
4. *Terminal* → container **api** → `php artisan giftcard:verify-chains` (the restored chains and balances must verify).

**Restore drill** (once a month, and before the first real cards; nothing in production changes):
1. Container **backup**:
   `mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE restore_test; GRANT SELECT ON restore_test.* TO '<DB_USERNAME>'@'%'"`,
   then `gunzip -c /backups/<newest>.sql.gz | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" restore_test`.
2. Container **api**: `DB_DATABASE=restore_test php artisan giftcard:verify-chains` → "All hash chains and voucher
   balances are intact." (a one-off read-only command; the running services keep their database).
3. Container **backup**: `mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE restore_test"`.
Record date, dump file and result in the operations log. The same drill run on MySQL 8.4 with the demo data
(2026-09-29): dump verified, 12 append-only triggers restored and enforcing, chains and balances intact.

## Operations

| Task | Where |
|---|---|
| Logs of a service | resource → *Logs* (all services log to stdout/stderr; Laravel uses `LOG_CHANNEL=stderr`) |
| Artisan command | *Terminal* → **api** → `php artisan …` (e.g. `migrate:status`, `schedule:list`, `queue:failed`) |
| Integrity check now | *Terminal* → **api** → `php artisan giftcard:verify-chains` (recomputes every hash chain and every voucher balance) |
| Change a setting | *Environment Variables* → *Redeploy* (configuration is cached at container start) |
| Monitoring | an uptime check on `https://<domain>/up` (Better Stack, UptimeRobot…); `OPS_ALERT_EMAIL` gets a mail when a queue exceeds 500 jobs and when the nightly integrity check fails. A failed integrity check is a security incident: preserve the database and the backups before changing anything |
| Logs without secrets | The gateway's access and error logs drop tokens, e-mail query parameters, cookies, `Authorization`, `X-Device-Id` and `Idempotency-Key`; every service rotates its Docker log at 10 MB × 5 files |

Scheduled jobs (times in `SCHEDULE_TIMEZONE`, default Europe/Vienna): every minute `giftcard:seal-security-events`
and `giftcard:monitor-security-events` (fraud rules → *Security alerts*, high/critical mailed), 00:15
`vouchers:expire`, 02:30 `giftcard:verify-chains`, 02:40 `cards:key-set:verify` (card keys against their key check
values), 03:30 `queue:prune-failed`, 10:00 `vouchers:notify-expiring`, hourly `ops:check-backups`, every 15 min
`auth:clear-resets`, every 5 min `queue:monitor`. Check with `php artisan schedule:list` in the api container.

## Staging

A second Coolify resource from the same repository and the same compose file, with its own domain (e.g.
`https://staging.giftcardpro.at`) and `APP_ENV=staging` in its Environment Variables (branch `main` or a `staging`
branch). It has its own database, Redis and volumes. Staging is held to the same rules as production (https URLs).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `api`/`worker`/`scheduler` stop with "No public URL" | The gateway has no domain. Step 4. |
| `api` fails with "app.url must be the https URL …" | The gateway domain is `http://…` (e.g. Coolify's generated sslip.io domain). Use an `https://` domain; for a quick test without your own domain, `https://<anything>.<server-ip>.sslip.io` works. |
| `api` stops with "DB_PASSWORD is empty" | Coolify did not generate `SERVICE_PASSWORD_MYSQL` (older Coolify versions). Set `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT` and `SERVICE_PASSWORD_REDIS` yourself (long random values) **before** the first deploy, then *Redeploy*. |
| `api` log repeats "MySQL not ready: … Access denied" after changing a password | The MySQL volume keeps the password of its first start. Put the old value back, or (only without data) delete the `mysql-data` volume. |
| A host answers `503 no available server` with the certificate `TRAEFIK DEFAULT CERT` (e.g. `api.giftcardpro.at`, bare `giftcardpro.at`) | That host is **not assigned to any service**: Coolify's proxy has no router for it, so its catch-all answers 503 and no Let's Encrypt certificate is requested. It is not a backend failure. The whole product, API included, is served by the `gateway` on its domain (`https://app.giftcardpro.at/api/v1`). The `api` container has **no Traefik labels by design** and no HTTP server: `curl http://127.0.0.1/up` fails and port 9000 is FastCGI (a plain HTTP request is reset). Test the API with `curl https://app.giftcardpro.at/up`, inside **gateway** with `wget -qO- http://127.0.0.1/up`, inside **api** with `SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000`. To serve an extra host, add it to *Domains for gateway*, comma-separated, canonical domain first (`https://app.giftcardpro.at,https://api.giftcardpro.at`), then *Redeploy*. Never give `api` a domain. |
| Certificate not issued / "not secure" | DNS does not point at the server yet, or ports 80/443 are closed. |
| 419 / sign-in loops in the dashboard | The browser URL differs from the gateway domain (cookies are bound to it). Use exactly the configured domain. |
| `env file /artifacts/<id>/.env not found` when you run `docker compose … config` by hand in Coolify's helper container | Not an error in the repository (it has no `env_file` and needs no `.env`). Coolify rewrites the compose file in `/artifacts/<id>/`, adds `env_file: .env` to every service, and writes that `.env` from the resource's *Environment Variables* only after the build, right before `docker compose up`. Validate the file from the repository instead: `docker compose -f docker-compose.coolify.yml config`. If a real deployment stops with this message, update Coolify (older 4.0.0-beta versions wrote the `.env` to a different directory, coollabsio/coolify#8953) and leave *Custom Start Command* empty. |
| Deployment stops with `required variable SERVICE_… is missing a value` | Fail-fast of `docker-compose.coolify.yml`: no container is created. `SERVICE_URL_GATEWAY` → give the **gateway** service an `https://` domain (step 4) and redeploy. `SERVICE_PASSWORD_*` → Coolify generates them when it reads the compose file; check *Environment Variables*, and set them yourself (long random values) only if they are missing. The same message appears when the file is started with plain `docker compose` on the server — such a stack is not the Coolify deployment (its containers are named `<project>-<service>-1` and have no `coolify.*` labels); remove it with `docker compose -p <project> down`. |
| Containers named `<something>-mysql-1` with empty `MYSQL_PASSWORD` | Not started by Coolify (Coolify names containers `<service>-<application uuid>` and labels them `coolify.managed=true`). Check with `docker inspect <container> --format '{{json .Config.Labels}}'`. |
| Invitations or password e-mails never arrive; red banner "E-mails are not delivered" in the admin | `MAIL_MAILER` is still `log` (Coolify pre-fills the default from the compose file). Set `MAIL_MAILER=smtp` and the `MAIL_*` values (step 5), *Redeploy*, then **System settings → Send test e-mail**, and **⋯ → Invite again** for owners who got nothing. Every attempt is in `notification_logs`. |
| **Send test e-mail** fails with `550 Unrouteable address` while invitations arrive | SMTP, login and sender work; the mail server refuses that one recipient (the response names it, the `api` log has "Platform test e-mail requested" with `recipient`). By default the test goes to the signed-in admin's own address — if that address or its domain has no mailbox (e.g. an admin created with `platform:create-admin` on a domain without MX record), enter another recipient in the field, or change the admin's e-mail. |
| The log stops after *Pulling & building required images* | Coolify hides the build output: open the deployment and switch on the debug log view to see it. The first build compiles PHP extensions and builds Next.js at the same time (5–15 min on 2 vCPU / 4 GB). Every download and the Next.js build have a hard time limit, so a stalled mirror ends the build with an error (exit code 143) instead of blocking; then *Redeploy*. If the server runs out of memory (`dmesg -T \| grep -i oom`), add swap or use a larger server. |
| Log shows "Added … ARG declarations to Dockerfile" | The compose file was changed so that a `dockerfile:` path no longer contains `${…}`. Restore it: without the variable, Coolify writes every environment variable (passwords, APP_KEY) into the image history. |
| Build fails at `pecl install redis`, `composer install` or `npm ci` | Temporary outage of pecl.php.net, GitHub or npm. *Redeploy*. |

## Scaling out

| Need | Step |
|---|---|
| More web traffic | Raise `pm.max_children` in `infra/docker/php/www.conf`, give the server more CPU; the app is stateless (sessions, cache, locks in Redis). |
| Database | Move MySQL to a managed database: set `DB_HOST`, `DB_PASSWORD` etc. and remove the `mysql`/`backup` services. |
| Isolation for enterprise customers | Deploy the same repository as its own Coolify resource per customer (single-tenant) — no code changes. |
