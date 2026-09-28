# Installation

> Step-by-step commands for every component (backend, dashboard, waiter app, NFC, database, release) are in
> [RUNNING_THE_PROJECT.md](../RUNNING_THE_PROJECT.md); this page adds background and details.

## Requirements

| Component | Version |
|---|---|
| PHP | 8.4 with `intl`, `pdo_mysql`, `gd`, `zip`, `bcmath`, `redis` (or `predis`) |
| Composer | 2.x |
| Node.js | 22 LTS |
| MySQL | 8.4 (MariaDB 10.11+ also works) |
| Redis | 7.x |

Docker users only need Docker 24+ with the compose plugin (see [DOCKER.md](DOCKER.md)).

## 1. Backing services

```bash
docker compose -f docker-compose.dev.yml up -d
```

This starts MySQL (`giftcard_pro` / `giftcard` / `secret`), Redis and Mailpit (UI on http://localhost:8025 —
every e-mail the app sends in development lands there).

## 2. API (Laravel)

```bash
cd backend
cp .env.example .env
composer install
php artisan key:generate
```

Set the database credentials in `.env` (`DB_PASSWORD=secret` for the dev compose file) and point mail at
Mailpit (`MAIL_HOST=127.0.0.1`, `MAIL_PORT=1025`). Then:

```bash
php artisan migrate --seed      # schema + roles/permissions + e-mail templates + demo data (local only)
php artisan serve               # http://localhost:8000
php artisan queue:work          # in a second terminal (e-mails)
php artisan schedule:work       # optional: nightly expiration & reminders
```

> **Zero-dependency mode:** set `DB_CONNECTION=sqlite`, `SESSION_DRIVER=database`, `CACHE_STORE=database`,
> `QUEUE_CONNECTION=sync` and create `database/database.sqlite` to run without MySQL/Redis.
> (Row locks are no-ops on SQLite — use MySQL for anything beyond UI work.)

## 3. Web app (Next.js)

```bash
cd dashboard
cp .env.example .env.local      # BACKEND_INTERNAL_URL=http://localhost:8000
npm install
npm run dev                     # http://localhost:3000
```

The dev server proxies `/api/*` and `/sanctum/*` to Laravel, so the browser talks to a single origin and
Sanctum session cookies work exactly as in production.

## 4. First platform administrator (production)

Demo data is never seeded in production. Create the operator account interactively:

```bash
php artisan platform:create-admin you@company.com --name="Your Name"
```

First open **System settings → E-mail delivery**: it shows the mailer and SMTP server in use. Press **Send test
e-mail** (to your own address by default, or any mailbox you enter). Only if a red banner appears on the platform
pages are e-mails written to the log (`MAIL_MAILER=log`) instead of being delivered.

Then open **Restaurants → Onboard restaurant**; the owner receives a welcome e-mail with a link to set their
password (valid 72 hours). The list shows each owner's invitation state (pending, expired, not delivered). If
the link expired or the address was mistyped: **⋯ → Invite again** (the address can be corrected there).

## 5. First restaurant

When the owner signs in for the first time, the dashboard shows a **Welcome** panel with the four steps to go
live — each links to the right page:

1. **Check your card rules** (Settings → Gift cards): minimum/maximum value, default validity, reloads,
   partial redemption, customer e-mails.
2. **Invite your team** (Team → Invite): managers and waiters receive their own 72-hour invitation.
3. **Issue the first gift card** (Gift cards → New gift card), then write the NFC tag or print the card.
4. **Open waiter mode on the phones** (sign in as a waiter — the waiter app opens automatically).

The panel disappears once the first card is sold. For staff training use the one-page
[user guide](USER_GUIDE.md); for the go-live day use the [pilot checklist](PILOT_CHECKLIST.md).

## 6. NFC keys (only for NTAG 424 DNA cards)

```bash
php artisan giftcard:nfc-keys
```

Copy the two keys into `.env`. See [NFC.md](NFC.md) before programming secure tags.

## Running the tests

```bash
cd backend && php artisan test          # 113 tests, SQLite in-memory (fast)
cd dashboard && npm run lint && npm run typecheck && npm run build
```

To run the suite against MySQL, see [DEVELOPMENT.md](DEVELOPMENT.md#testing-against-mysql).
