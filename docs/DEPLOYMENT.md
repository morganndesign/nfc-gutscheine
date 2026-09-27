# Deployment (Hetzner Cloud)

The reference setup runs the whole product on **one Hetzner Cloud server** (CPX31: 4 vCPU / 8 GB is plenty for
hundreds of restaurants) with Docker Compose. Scale-out paths are listed at the end.

## Go-live: first deployment of giftcardpro.at

The complete order for the first production deployment. Sections 1–7 below explain each part in more depth.
Allow about two hours. Replace `app.giftcardpro.at` everywhere if you choose another host name — then also
`waiter-app/config/production.json` (the iOS app-link host follows it automatically) and the three URLs in
`backend/.env.production`, and build a new app.

**You need:** the domain `giftcardpro.at`, a Hetzner Cloud account, an e-mail sending service (e.g. Postmark,
Mailgun, Brevo — SMTP credentials), your SSH key, and the project folder on your Mac.

1. **Register the domain** `giftcardpro.at` with an `.at` registrar (e.g. Hetzner, INWX, World4You). Use the
   registrar's DNS or Hetzner DNS.
2. **Create the server** (section 1): Hetzner Cloud → *Add server* → Falkenstein or Nürnberg, **Ubuntu 24.04**,
   **CPX31**, your SSH key, *Backups* on, a *Firewall* allowing 22 (your IP only), 80 and 443. Note the IPv4 and IPv6.
3. **DNS records** at the domain:
   | Type | Name | Value |
   |---|---|---|
   | A | `app` | server IPv4 |
   | AAAA | `app` | server IPv6 |
   | TXT / CNAME | as given by the mail service | SPF, DKIM (and `_dmarc` TXT `v=DMARC1; p=none; rua=mailto:you@…`) |

   Wait until `dig +short app.giftcardpro.at` (on your Mac) returns the IPv4 — HTTPS certificates are only issued then.
4. **Prepare the server** (as root, then as `deploy`):
   ```bash
   adduser deploy && usermod -aG sudo deploy && cp -r ~/.ssh /home/deploy/ && chown -R deploy: /home/deploy/.ssh
   # /etc/ssh/sshd_config: PasswordAuthentication no, PermitRootLogin no → systemctl restart ssh
   apt update && apt -y upgrade && apt -y install unattended-upgrades fail2ban rsync
   curl -fsSL https://get.docker.com | sh && usermod -aG docker deploy
   mkdir -p /opt/giftcard-pro && chown deploy: /opt/giftcard-pro
   ```
5. **Copy the code** from your Mac (no Git repository needed; with one, `git clone` instead — then CI/CD in
   section 4 deploys every later release):
   ```bash
   cd ~/Documents/Claude/Projects/Gutscheine/GiftCardPro
   rsync -az --delete --exclude node_modules --exclude vendor --exclude .next --exclude waiter-app \
     --exclude releases --exclude signing --exclude e2e --exclude 'backend/.env' --exclude '*.sqlite' \
     --exclude 'backend/storage/logs/*' ./ deploy@app.giftcardpro.at:/opt/giftcard-pro/
   ```
6. **Build the images on the server** (no registry needed):
   ```bash
   cd /opt/giftcard-pro
   docker build -f backend/Dockerfile -t local/giftcard-pro-api:latest .
   docker build -t local/giftcard-pro-web:latest dashboard
   ```
7. **Configuration.** `cp .env.production.example .env.production` and
   `cp backend/.env.production.example backend/.env.production`, then edit both:
   - `.env.production`: `APP_DOMAIN=app.giftcardpro.at`, `ACME_EMAIL=<your e-mail>`, **`REGISTRY=local`**,
     `IMAGE_TAG=latest`, `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `REDIS_PASSWORD` (each `openssl rand -base64 36`),
     leave the three `WAITER_*` empty for now.
   - `backend/.env.production`: the **same** `DB_PASSWORD` and `REDIS_PASSWORD`;
     `APP_KEY=` the output of `echo "base64:$(openssl rand -base64 32)"`;
     mail: `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM_ADDRESS=no-reply@giftcardpro.at`;
     URLs, session and Sanctum domains are already `app.giftcardpro.at`; `SEED_DEMO_DATA=false`.
     Optional (NTAG 424 DNA cards): `docker run --rm --entrypoint php local/giftcard-pro-api:latest artisan giftcard:nfc-keys`
     (`--entrypoint php` skips the container's start script, which would try to migrate a database that is not running yet).
   - Store `APP_KEY`, the passwords and the NFC keys in your password manager.
8. **Start:**
   ```bash
   docker compose --env-file .env.production up -d
   docker compose --env-file .env.production ps               # all "healthy" / "running" after ~2 min
   docker compose --env-file .env.production logs -f api caddy # migrations, certificate
   ```
   The api container runs the migrations and reference seeders itself. Caddy fetches the Let's Encrypt
   certificate on the first HTTPS request.
9. **First administrator:**
   `docker compose --env-file .env.production exec api php artisan platform:create-admin you@giftcardpro.at --name="Your Name"`
10. **Check:**
    ```bash
    curl -fsS https://app.giftcardpro.at/up
    curl -fsS "https://app.giftcardpro.at/api/v1/app/config?platform=android&version=1.4.2"   # JSON
    ```
    Sign in at https://app.giftcardpro.at, onboard a test restaurant, and confirm the welcome e-mail arrives.
11. **Backups** (section 5): add the two cron lines, set up the off-site copy, and **test one restore**
    ([RUNNING_THE_PROJECT.md §7.3](../RUNNING_THE_PROJECT.md#73-restore-a-backup)).
12. **Monitoring** (section 7): an uptime check on `https://app.giftcardpro.at/up`.
13. **Waiter app on real phones:** `cd waiter-app && tool/release.sh android production` (`config/production.json`
    already points at `https://app.giftcardpro.at/api/v1`), install
    `build/dist/giftcard-waiter-production-<version>.apk`, sign in with a waiter of the test restaurant.
14. **App links** (card links open the app): in `.env.production` set
    `WAITER_ANDROID_PACKAGE=eu.tapredeem.waiter`,
    `WAITER_ANDROID_CERT_SHA256=<upload key SHA-256>,<Play app signing key SHA-256>` (see `signing/ANDROID_SIGNING.md`),
    `WAITER_IOS_APP_IDS=<Team ID>.eu.tapredeem.waiter`, then `docker compose --env-file .env.production up -d web`.
    Check `https://app.giftcardpro.at/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association`.
15. **Stores:** Play internal testing and TestFlight ([MOBILE_RELEASE.md](MOBILE_RELEASE.md)); before the first
    restaurant: [PILOT_CHECKLIST.md](PILOT_CHECKLIST.md).
16. **Record it** in `CURRENT_VERSION.md` → *Current production release* (version, date, server).

**Later updates without CI:** repeat step 5 (rsync), step 6 (build), then
`docker compose --env-file .env.production up -d` — new migrations run automatically.

## 1. Server

1. Create an Ubuntu 24.04 server in Falkenstein/Nürnberg (EU data residency), add your SSH key,
   enable **backups** and attach a **Cloud Firewall** allowing only 22 (from your IPs), 80 and 443.
2. Point `APP_DOMAIN` (e.g. `app.giftcardpro.at`) A/AAAA records at the server.
3. Harden & install Docker:

```bash
adduser deploy && usermod -aG sudo deploy
# /etc/ssh/sshd_config: PasswordAuthentication no, PermitRootLogin no
apt update && apt -y upgrade && apt -y install unattended-upgrades fail2ban git
curl -fsSL https://get.docker.com | sh && usermod -aG docker deploy
```

## 2. Application directory

```bash
sudo mkdir -p /opt/giftcard-pro && sudo chown deploy: /opt/giftcard-pro
cd /opt/giftcard-pro
git clone git@github.com:your-org/giftcard-pro.git .
cp .env.production.example .env.production           # compose variables
cp backend/.env.production.example backend/.env.production
```

Fill in both files. Generate secrets:

```bash
openssl rand -base64 36                               # DB / Redis passwords
echo "base64:$(openssl rand -base64 32)"                                            # APP_KEY
docker run --rm --entrypoint php ghcr.io/your-org/giftcard-pro-api:latest artisan giftcard:nfc-keys   # NTAG 424 keys (optional)
```

> Store `APP_KEY` and the NTAG 424 keys in your password manager. Losing `APP_KEY` logs everyone out;
> losing the NFC keys makes secure tags unverifiable.

## 3. First start

```bash
docker login ghcr.io
docker compose --env-file .env.production up -d
docker compose --env-file .env.production exec api php artisan platform:create-admin you@company.com
```

Caddy requests the TLS certificate on the first HTTPS request. Check `https://APP_DOMAIN/up` → `200`.

## 4. CI/CD (GitHub Actions)

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | every push / PR | Pint, Larastan, PHPUnit on SQLite **and MySQL 8.4**, `composer audit`; ESLint, `tsc`, `next build`, `npm audit`; Docker build. |
| `deploy.yml` | tag `v*` or manual | Builds & pushes both images to GHCR tagged with the commit SHA, then SSHes into the server and runs `infra/scripts/deploy.sh`. |

Repository configuration:

| Name | Type | Value |
|---|---|---|
| `DEPLOY_HOST` | secret | server IP / host |
| `DEPLOY_USER` | secret | `deploy` |
| `DEPLOY_SSH_KEY` | secret | private key of a deploy key allowed on the server |
| `DEPLOY_HOST_FINGERPRINT` | secret | `ssh-keyscan -t ed25519 host \| ssh-keygen -lf -` |
| `GHCR_READ_TOKEN` | secret | PAT with `read:packages` |
| `APP_DOMAIN` | variable | `app.giftcardpro.at` |
| `production` | environment | add required reviewers for manual approval |

Release: `git tag v1.4.0 && git push --tags`.

`deploy.sh` pulls the new images, starts the API (which migrates), rolls workers/scheduler/web, restarts queue
workers gracefully and health-checks `/up`. Migrations are written to be backwards compatible with the
previous release (expand → migrate → contract), so the old web container keeps working during the rollout.

## 5. Backups

```cron
# crontab -e (deploy user)
30 2 * * * cd /opt/giftcard-pro && docker compose --env-file .env.production --profile backup run --rm backup >> /var/log/giftcard-backup.log 2>&1
45 2 * * * rclone sync /opt/giftcard-pro/backups storagebox:giftcard-backups
```

- Logical dumps (`--single-transaction`, consistent without locking) are kept 14 days locally.
- Sync them off-site (Hetzner Storage Box via rclone/borg).
- Hetzner server backups add daily full-disk snapshots.
- **Test restores** monthly: `gunzip -c dump.sql.gz | docker compose exec -T mysql mysql -u root -p giftcard_pro_restore`.

## 6. Nightly jobs

The `scheduler` container runs `schedule:work`; times are local (`SCHEDULE_TIMEZONE`, default Europe/Vienna):

| Time | Job |
|---|---|
| 00:15 | `giftcards:expire` — expires due cards (ledgered, audited; one failing card never stops the batch) |
| 03:30 | `queue:prune-failed` (keeps 30 days) |
| 10:00 | `giftcards:notify-expiring` — reminder e-mails for active restaurants only |
| every 15 min | `auth:clear-resets` |
| every 5 min | `queue:monitor` (Redis queues, alerts above 500 waiting jobs) |

Check with `docker compose exec scheduler php artisan schedule:list`. Queue workers and the scheduler only start
once the `api` container is healthy, i.e. after migrations finished; `migrate --isolated` guarantees that two app
containers never migrate concurrently.

## 7. Monitoring

- Uptime: monitor `https://APP_DOMAIN/up` (Better Stack, UptimeRobot…). It checks the database and cache, not just PHP.
- Security: alert on `warning` log lines — `Suspicious gift card scan` (cloned/replayed/foreign cards) and `Account locked`.
- Logs: `docker compose logs` (JSON from Caddy, stderr from Laravel); ship with Vector/Promtail if desired.
- Errors: add Sentry (`sentry/sentry-laravel`, `@sentry/nextjs`) — both only need a DSN.
- Queue health: `queue:monitor` runs every 5 minutes from the scheduler and fires `QueueBusy` above 500 jobs.

## 8. Updating PHP / Node / MySQL

Base images are pinned by major version. Rebuilding picks up patch releases; bump majors in the Dockerfiles
and compose file deliberately and let CI verify.

## Scaling out

| Need | Step |
|---|---|
| More web traffic | Run several `api` and `web` replicas behind Caddy (`reverse_proxy` accepts multiple upstreams). The app is stateless — sessions, cache and locks live in Redis. |
| Database | Move to a managed MySQL or a dedicated server; add a read replica for exports/reports. |
| Isolation for enterprise customers | Deploy the same images per customer (single-tenant) — no code changes. |
