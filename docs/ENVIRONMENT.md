# Environment variables

## Environments — one strategy for every component

Every component takes its addresses from **one file per environment**; no server address is written in the code.
Code only contains *local development defaults* (`localhost`), and every component refuses to run in staging or
production with such a default.

| | Development (your computer) | Staging | Production |
|---|---|---|---|
| **Backend** (`backend/`) | `backend/.env` from `.env.example` · `APP_ENV=local` | Coolify resource *Environment Variables* (`APP_ENV=staging`, own domain) — reference: `.env.production.example` | Coolify resource *Environment Variables* — reference: `.env.production.example` |
| **Server stack** | `docker-compose.dev.yml` (MySQL, Redis, Mailpit; no variables) | `docker-compose.coolify.yml` (same file) | `docker-compose.coolify.yml` |
| **Dashboard** (`dashboard/`) | `dashboard/.env.local` from `.env.example` (`BACKEND_INTERNAL_URL`) | nothing — same origin, the gateway routes `/api` | nothing — same origin, the gateway routes `/api` |
| **Waiter app** (`waiter-app/`) | `config/development.json` (+ your `development.local.json`) · `APP_ENV=development` | `config/staging.json` · `APP_ENV=staging` | `config/production.json` · `APP_ENV=production` |

Backend and dashboard read their settings **at run time** (development: the files above; staging/production: the
variables of the Coolify resource, passed to the containers by `docker-compose.coolify.yml`); the waiter app reads its file
**at build time** (a phone has no server-side files) — so an app build belongs to exactly one environment.

What keeps the environments apart:

| Risk | Protection |
|---|---|
| Production app talks to a development or staging server | `APP_ENV=production` builds accept only https, cannot change their server in the app (a stored override is ignored), and `tool/release.sh` refuses a config file whose `APP_ENV` does not match the environment asked for. |
| Development app talks to production by accident | `config/development.json` points at your computer; production is reached only if you put its address in a development file or type it in the DEV ribbon. A build without any config file stops on "App not set up correctly" (no default address). |
| A sign-in of one server is sent to another | The app remembers which server a sign-in belongs to and signs out when the server differs (relevant on iPhone, where all environments share one app id; on Android each environment is a separate app). |
| Staging/production API prints `localhost` links | The API refuses to start when `APP_ENV` is `staging`/`production` and `APP_URL`, `FRONTEND_URL` or `CARD_BASE_URL` is missing, not https, a placeholder, `localhost`/`127.0.0.1`/`10.0.2.2` or `*.test`/`*.local` (`App\Support\EnvironmentGuard`). |
| Production dashboard forwards `/api` to a development machine | `BACKEND_INTERNAL_URL` has no default; it is only set in development (`next dev` stops with a message when it is missing). |
| App links of one environment in another app | Android: the intent-filter host comes from the build's `CARD_DOMAINS`; iOS: `tool/release.sh` writes the Associated Domains host into `ios/Flutter/Environment.xcconfig` for the environment being built. |

Keep in step within one environment: the waiter app's `CARD_DOMAINS` = host of the backend's `CARD_BASE_URL`; the
app's `API_BASE_URL` = `APP_URL` + `/api/v1` (same origin in staging/production).

## API (`backend/.env`)

### Application

| Variable | Example | Description |
|---|---|---|
| `APP_NAME` | `GiftCard Pro` | Shown in e-mails. |
| `APP_ENV` | `production` | `local`, `testing`, `staging`, `production`. Demo data is seeded automatically in `local`/`staging`. |
| `APP_KEY` | `base64:…` | Encryption key for cookies, sessions and encrypted values. `php artisan key:generate --show`. **Never rotate without a plan** — sessions become invalid. |
| `APP_DEBUG` | `false` | Must be `false` in production (stack traces leak secrets). |
| `APP_URL` | `https://app.example.com` | Public origin of the API (same as the frontend with the default single-origin setup). |
| `FRONTEND_URL` | `https://app.example.com` | Used for password-reset links. |
| `CARD_BASE_URL` | `https://app.example.com` | Base of the URL written to NFC tags and QR codes: `{CARD_BASE_URL}/c/{token}`. **Changing it after cards were written breaks existing cards** — choose a domain you will keep. |
| `BCRYPT_ROUNDS` | `12` | Password hashing cost. |
| `APP_TIMEZONE` | `UTC` | Keep `UTC`: all timestamps are stored in UTC and converted per restaurant. |
| `SCHEDULE_TIMEZONE` | `Europe/Vienna` | Local clock for nightly jobs: card expiry 00:15, expiry reminders 10:00, cleanup 03:30. |
| `LOG_LEVEL` | `info` | `info` in production (security warnings — locked accounts, suspicious scans — are `warning`). Use `debug` locally: the `log` mailer writes invitation/reset e-mails at debug level. |

### Database, cache, queues

| Variable | Default | Description |
|---|---|---|
| `DB_CONNECTION` | `mysql` | `mysql` (production), `mariadb`, `sqlite` (dev/tests). |
| `DB_HOST` / `DB_PORT` / `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` | | Connection. |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` / `REDIS_CLIENT` | `phpredis` | Redis for cache, sessions, queues and rate limits. |
| `CACHE_STORE` | `redis` | Also backs rate limiting and the permission cache. |
| `QUEUE_CONNECTION` | `redis` | E-mails are queued on `notifications`. |
| `QUEUE_FAILED_DRIVER` | `database-uuids` | Failed jobs are stored with UUID keys. |

### Sessions & authentication

| Variable | Default | Description |
|---|---|---|
| `SESSION_DRIVER` | `redis` | |
| `SESSION_LIFETIME` | `480` | Minutes of inactivity before sign-out (a full service shift). |
| `SESSION_ENCRYPT` | `true` | Encrypt session payloads at rest. |
| `SESSION_SECURE_COOKIE` | `true` (prod) | Cookie only over HTTPS. |
| `SESSION_SAME_SITE` | `lax` | CSRF defence-in-depth. |
| `SESSION_DOMAIN` | `app.example.com` | Host of the web app. |
| `SANCTUM_STATEFUL_DOMAINS` | `app.example.com` | Hosts whose browser requests use cookie sessions (comma-separated, with port in dev). |
| `SANCTUM_TOKEN_PREFIX` | `gcp_` | Prefix of API tokens — enables secret scanning (GitHub push protection etc.). |

### Security tuning

| Variable | Default | Description |
|---|---|---|
| `SCAN_FAILURE_LIMIT` | `10` | Failed card lookups (unknown/foreign cards) per user **and** per IP before lookups are blocked. |
| `SCAN_FAILURE_DECAY` | `300` | Window in seconds for the above. |
| `LOGIN_LOCKOUT_THRESHOLD` | `10` | Consecutive wrong passwords before the account is locked. |
| `LOGIN_LOCKOUT_MINUTES` | `15` | Lock duration. |
| `API_TOKEN_MAX_DAYS` | `365` | Maximum lifetime of integration tokens. |
| `DEVICE_TOKEN_DAYS` | `30` | Sign-in lifetime of the native waiter app. Renewed while the phone is in use, so only a phone unused for this long has to sign in again. |

### NFC

| Variable | Description |
|---|---|
| `NTAG424_META_READ_KEY` | AES-128 key (32 hex) that decrypts PICC data (UID + tap counter). |
| `NTAG424_FILE_READ_KEY` | AES-128 master key for the SUN CMAC. |
| `NTAG424_DIVERSIFY_KEYS` | `true`: per-chip MAC key = HMAC-SHA256(master, UID)[0..16]. Recommended. |

### Notifications

| Variable | Default | Description |
|---|---|---|
| `CARD_EXPIRING_NOTICE_DAYS` | `30` | Reminder e-mail this many days before expiry. |
| `CARD_LOW_BALANCE_THRESHOLD` | `500` | Cents. "Balance running low" e-mail when a redemption crosses it. |
| `OPS_ALERT_EMAIL` | *(support e-mail)* | Receives operations alerts, e.g. a queue with more than 500 waiting jobs (at most one e-mail per queue every 30 min). |
| `MAIL_*` | | Standard Laravel mail settings (SMTP / Postmark / SES). |

### Misc

| Variable | Description |
|---|---|
| `SEED_DEMO_DATA` | `true` seeds the demo restaurant outside `local`/`staging`. Never in production. |
| `LOG_CHANNEL` | `stderr` in containers (collected by Docker). |

## Web app (`dashboard/.env.local`)

| Variable | Description |
|---|---|
| `BACKEND_INTERNAL_URL` | Development only: where `next dev` proxies `/api` and `/sanctum`. In production the gateway (Caddy, `infra/docker/gateway`) routes these paths to Laravel before they reach Next.js. |

The web app has **no secrets**: it only talks to its own origin.

## Production and staging (Coolify)

The server stack is `docker-compose.coolify.yml`; its variables are set in Coolify (resource → *Environment
Variables*). **Every variable has a working default** — the full, commented list is
[`.env.production.example`](../.env.production.example). The Laravel variables above that are not listed there are
fixed in the compose file (Redis sessions, secure cookies, `LOG_CHANNEL=stderr`, …).

| Set by | Variables |
|---|---|
| Coolify, automatically | `SERVICE_URL_GATEWAY` / `SERVICE_FQDN_GATEWAY` (domain of the `gateway` service → `APP_URL`, `FRONTEND_URL`, `CARD_BASE_URL`, `SESSION_DOMAIN`, `SANCTUM_STATEFUL_DOMAINS`, default `MAIL_FROM_ADDRESS`), `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` |
| The first deploy, automatically | `APP_KEY` (kept in the `laravel-storage` volume unless you set `APP_KEY` yourself) |
| You (needed for real use) | `MAIL_*` (SMTP), later `WAITER_ANDROID_CERT_SHA256`, `WAITER_IOS_APP_IDS` |
| You (optional) | `APP_ENV` (`staging`), `APP_URL`, `OPS_ALERT_EMAIL`, `NTAG424_*`, `SCHEDULE_TIMEZONE`, `LOG_LEVEL`, `BACKUP_TIME`, `BACKUP_KEEP_DAYS`, `MYSQL_INNODB_BUFFER_POOL_SIZE`, `DB_DATABASE`/`DB_USERNAME` (before the first deploy only) |

| Variable (web service) | Description |
|---|---|
| `WAITER_IOS_APP_IDS` | Waiter app IDs for iPhone Universal Links, `TEAMID.bundle.id` (comma-separated). Served as `/.well-known/apple-app-site-association`. Empty = 404. |
| `WAITER_ANDROID_PACKAGE` | Package name of the Android waiter app for App Links (`/.well-known/assetlinks.json`). |
| `WAITER_ANDROID_CERT_SHA256` | SHA-256 signing certificate fingerprints (Play App Signing, plus the upload key for internal builds), comma-separated `AB:CD:…`. |
