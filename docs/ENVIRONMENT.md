# Environment variables

## Environments — one strategy for every component

Every component takes its addresses from **one source per environment**; no server address is written in the
code. Code contains only local development defaults (`localhost`), and every component refuses to run in staging or
production with such a default.

| | Development (your computer) | Staging | Production |
|---|---|---|---|
| **Backend** (`backend/`) | `backend/.env` from `.env.example` · `APP_ENV=local` | Coolify resource *Environment Variables* (`APP_ENV=staging`, own domain) — reference: `.env.production.example` | Coolify resource *Environment Variables* — reference: `.env.production.example` |
| **Server stack** | `docker-compose.dev.yml` (MySQL, Redis, Mailpit; no variables) | `docker-compose.coolify.yml` (same file) | `docker-compose.coolify.yml` |
| **Dashboard** (`dashboard/`) | `dashboard/.env.local` from `.env.example` (`BACKEND_INTERNAL_URL`) | nothing — same origin, the gateway routes `/api` | nothing — same origin, the gateway routes `/api` |
| **Waiter app** (`waiter-app/`) | `config/development.json` (+ your `development.local.json`) · `APP_ENV=development` | `config/staging.json` · `APP_ENV=staging` | `config/production.json` · `APP_ENV=production` |

Backend and dashboard read their settings **at run time**; the waiter app reads its file **at build time** (a phone
has no server-side files), so an app build belongs to exactly one environment.

| Risk | Protection |
|---|---|
| Production app talks to a development or staging server | `APP_ENV=production` builds accept only https and cannot change their server in the app (a stored override is ignored); `tool/release.sh` refuses a config file whose `APP_ENV` does not match the environment asked for. |
| Development app talks to production by accident | `config/development.json` points at your computer. A build without any config file stops on "App not set up correctly" (no default address). |
| A sign-in of one server is sent to another | The app remembers which server a sign-in belongs to and drops it when the server differs (relevant on iPhone, where all environments share one bundle id). |
| Staging/production API prints `localhost` links | The API refuses to start when `APP_ENV` is `staging`/`production` and `APP_URL` or `FRONTEND_URL` is missing, not https, a placeholder, `localhost`/`127.0.0.1`/`10.0.2.2` or `*.test`/`*.local` (`App\Support\EnvironmentGuard`). |
| Production dashboard forwards `/api` to a development machine | `BACKEND_INTERNAL_URL` has no default; it is set only in development (`next dev` stops with a message when it is missing). |

Keep in step within one environment: the app's `API_BASE_URL` = `APP_URL` + `/api/v1`.

## API (`backend/.env`)

### Application

| Variable | Example | Description |
|---|---|---|
| `APP_NAME` | `GiftCard Pro` | Shown in e-mails. |
| `APP_ENV` | `production` | `local`, `testing`, `staging`, `production`. Demo data is seeded in `local`, `testing` and `staging`. |
| `APP_KEY` | `base64:…` | Encryption key for cookies, sessions and encrypted values (`php artisan key:generate --show`). Changing it signs everybody out and makes encrypted values unreadable. |
| `APP_DEBUG` | `false` | Must be `false` outside development. |
| `APP_URL` | `https://app.example.com` | Public origin of the API (the same as the dashboard). |
| `FRONTEND_URL` | `https://app.example.com` | Base of invitation and password-reset links. |
| `BCRYPT_ROUNDS` | `12` | Password hashing cost. |
| `APP_TIMEZONE` | `UTC` | Keep `UTC`: timestamps are stored in UTC and converted per restaurant. |
| `SCHEDULE_TIMEZONE` | `Europe/Vienna` | Local clock of the nightly jobs: expiry 00:15, integrity check 04:00, cleanup 03:30, expiry reminders 10:00. |
| `LOG_LEVEL` | `info` | `info` in production (locked accounts are logged as `warning`, a failed integrity check as `critical`). Use `debug` locally: the `log` mailer writes e-mails at debug level. |

### Database, cache, queues

| Variable | Default | Description |
|---|---|---|
| `DB_CONNECTION` | `mysql` | `mysql` (production), `sqlite` (development, tests). The append-only triggers exist for MySQL/MariaDB and SQLite. |
| `DB_HOST` / `DB_PORT` / `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` | | Connection. |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` / `REDIS_CLIENT` | `phpredis` | Redis for cache, sessions, queues and rate limits. |
| `CACHE_STORE` | `redis` | Also backs rate limiting and the presentment lockout. |
| `QUEUE_CONNECTION` | `redis` | Every e-mail is sent from the queue (`default`, `notifications`). |
| `QUEUE_FAILED_DRIVER` | `database-uuids` | Failed jobs are stored with UUID keys. |

### Sessions and authentication

| Variable | Default | Description |
|---|---|---|
| `SESSION_DRIVER` | `redis` | |
| `SESSION_LIFETIME` | `480` | Minutes of inactivity before sign-out (a full service shift). |
| `SESSION_ENCRYPT` | `true` | Encrypt session payloads at rest. |
| `SESSION_SECURE_COOKIE` | `true` (servers) | Cookie only over HTTPS. |
| `SESSION_SAME_SITE` | `lax` | |
| `SESSION_DOMAIN` | `app.example.com` | Host of the web app. |
| `SANCTUM_STATEFUL_DOMAINS` | `app.example.com` | Hosts whose browser requests use cookie sessions (comma-separated, with port in development). |
| `SANCTUM_TOKEN_PREFIX` | `gcp_` | Prefix of tokens — enables secret scanning. |

### Security tuning

| Variable | Default | Description |
|---|---|---|
| `PRESENTMENT_FAILURE_LIMIT` | `10` | Failed voucher scans per restaurant, user and device before a short lockout (`429 PRESENTMENT_THROTTLED`). |
| `PRESENTMENT_FAILURE_DECAY` | `300` | Window of the above, in seconds. |
| `LOGIN_LOCKOUT_THRESHOLD` | `10` | Consecutive wrong passwords before the account is locked. |
| `LOGIN_LOCKOUT_MINUTES` | `15` | Lock duration. |
| `API_TOKEN_MAX_DAYS` | `365` | Maximum lifetime of integration tokens. |
| `DEVICE_TOKEN_DAYS` | `30` | Sign-in lifetime of the waiter app, renewed while the phone is in use. |

Fixed in `config/giftcard.php`: presentment lifetime 60 s, sale replay window 15 min, idempotency key length ≤ 96.

### Voucher limits (platform ceilings)

| Variable | Default | Description |
|---|---|---|
| `LIMIT_MAX_VOUCHER_BALANCE` | `50000` | Highest `max_voucher_balance` a restaurant may set (cents). |
| `LIMIT_MAX_DEBIT_PER_TRANSACTION` | `25000` | Highest `max_debit_per_transaction`. |
| `LIMIT_MAX_DEBIT_PER_VOUCHER_PER_DAY` | `50000` | Highest `max_debit_per_voucher_per_day`. |

A restaurant validity is at least 36 months (`min_validity_months`, fixed).

### Mail and notifications

| Variable | Default | Description |
|---|---|---|
| `MAIL_MAILER` | `failover` (dev), `log` (Coolify default) | `smtp` for real delivery. With `log`, e-mails are only written to the log and the platform admin shows a red banner. |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_SCHEME`, `MAIL_USERNAME`, `MAIL_PASSWORD` | | SMTP server (`MAIL_SCHEME`: `smtp` = STARTTLS on 587, `smtps` = TLS on 465). |
| `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | `no-reply@<domain>`, `GiftCard Pro` | Sender. |
| `MAIL_TIMEOUT` | `10` | Seconds before a slow mail server is given up (the job is retried). |
| `MAIL_LOCALE` | `de` | Language of invitation e-mails when the restaurant's language has no translation. |
| `MAIL_VERIFY_DOMAINS` | `true` | *Send test e-mail* refuses a recipient domain without a mail server. |
| `VOUCHER_EXPIRING_NOTICE_DAYS` | `30` | Expiry reminder this many days before the last valid day. |
| `OPS_ALERT_EMAIL` | *(support e-mail)* | Operations alerts: a queue with more than 500 waiting jobs, a failed integrity check, a stale backup, high and critical security alerts. |
| `CRYPTO_PROVIDER` | `local` | `local`: card keys in one encrypted keystore file. All key use goes through `App\Crypto\CryptoProvider`; an HSM provider replaces it without code changes. |
| `CRYPTO_KEYSTORE_PATH` | `storage/app/private/crypto/keystore.json` | Keystore file, in the `laravel-storage` volume; the daily backup copies it. |
| `CRYPTO_KEYSTORE_KEY` | — | **Required on staging and production** (the API refuses to start without it): `base64:` + 32 random bytes (`openssl rand -base64 32`). The only key in the environment; keep a copy offline, never next to the keystore. Rotation: `CRYPTO_KEYSTORE_NEW_KEY` + `php artisan crypto:keystore:rekey`. |
| `TAP_URL` | `APP_URL` + `/t` | Written into every card at the station (`{TAP_URL}/{key set}?e=…&m=…` opens the guest page). **Permanent once the first card is personalised**; must be https on staging/production. |
| `FRAUD_COUNTER_GAP` | `50` | Card reads between two verified taps above which a card is flagged (*Security alerts*). |

### Development only

| Variable | Description |
|---|---|
| `SEED_DEMO_DATA` | `true` seeds the demo restaurants outside `local`/`testing`/`staging`. The Coolify stack fixes it to `false`. |
| `LOG_CHANNEL` | `stack` locally; `stderr` in containers. |

## Dashboard (`dashboard/.env.local`)

| Variable | Description |
|---|---|
| `BACKEND_INTERNAL_URL` | Development only: where `next dev` forwards `/api` and `/sanctum`. On servers the gateway (Caddy, `infra/docker/gateway`) routes these paths to Laravel before they reach Next.js. |

The dashboard has **no secrets**: it only talks to its own origin.

## Waiter app (`waiter-app/config/<environment>.json`)

| Key | Description |
|---|---|
| `APP_ENV` | `development`, `staging`, `production`. http is allowed only in development; development and staging get their own Android application id and a corner badge. |
| `API_BASE_URL` | API root ending in `/api/v1`. |
| `APP_STORE_URL` | App Store listing opened by "Update required" (iOS production). |
| `PLAY_STORE_URL` | Optional; defaults to the Play listing of the package. |

## Production and staging (Coolify)

The server stack is `docker-compose.coolify.yml`; its variables are set in Coolify (resource → *Environment
Variables*). **Every variable has a working default** — the commented list is
[`.env.production.example`](../.env.production.example). The Laravel variables above that are not listed there are
fixed in the compose file (Redis sessions, secure cookies, `LOG_CHANNEL=stderr`, `SEED_DEMO_DATA=false`) or keep
their defaults from `config/giftcard.php`.

| Set by | Variables |
|---|---|
| Coolify, automatically | `SERVICE_URL_GATEWAY` / `SERVICE_FQDN_GATEWAY` (domain of the `gateway` service → `APP_URL`, `FRONTEND_URL`, `SESSION_DOMAIN`, `SANCTUM_STATEFUL_DOMAINS`, default `MAIL_FROM_ADDRESS`, derived in `infra/docker/php/entrypoint.sh`), `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` |
| The first deploy, automatically | `APP_KEY` (kept in the `laravel-storage` volume unless you set `APP_KEY` yourself) |
| You (needed for real use) | `MAIL_MAILER=smtp` and the `MAIL_*` values; `CRYPTO_KEYSTORE_KEY` (the API does not start without it); `TAP_URL` before the first card is personalised; `OFFSITE_SFTP_*` and `OFFSITE_CRYPT_*` ([Backups](DEPLOYMENT.md#backups)) |
| You (optional) | `APP_ENV` (`staging`), `APP_URL`, `APP_LOCALE`, `OPS_ALERT_EMAIL`, `MAIL_LOCALE`, `MAIL_TIMEOUT`, `SCHEDULE_TIMEZONE`, `LOG_LEVEL`, `BACKUP_TIME`, `BACKUP_KEEP_DAYS`, `OFFSITE_TIME`, `OFFSITE_KEEP_DAYS`, `DB_DATABASE`/`DB_USERNAME` (before the first deploy only) |

The `web` service needs no variables.
