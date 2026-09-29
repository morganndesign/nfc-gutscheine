# Installation

> Step-by-step commands for every component (backend, dashboard, waiter app, database, release) are in
> [RUNNING_THE_PROJECT.md](../RUNNING_THE_PROJECT.md); this page adds background and details.

## Requirements

| Component | Version |
|---|---|
| PHP | 8.4 with `intl`, `pdo_mysql`, `pdo_sqlite`, `gd`, `zip`, `bcmath`, `redis` (or `predis`) |
| Composer | 2.x |
| Node.js | 22 LTS |
| MySQL | 8.4 |
| Redis | 7.x |

Docker users only need Docker 24+ with the compose plugin (see [DOCKER.md](DOCKER.md)).

## 1. Backing services

```bash
docker compose -f docker-compose.dev.yml up -d
```

This starts MySQL (`giftcard_pro` / `giftcard` / `secret`, root password `root`), Redis and Mailpit (UI on
http://localhost:8025 — every e-mail the app sends in development lands there). MySQL runs with
`--log-bin-trust-function-creators=1`, which the append-only triggers need.

## 2. API (Laravel)

```bash
cd backend
cp .env.example .env
composer install
php artisan key:generate
```

Set `DB_PASSWORD=secret` in `.env` for the dev compose file. Mail needs no setting: `MAIL_MAILER=failover` sends
to Mailpit when it runs and otherwise writes to the log. Then:

```bash
php artisan migrate --seed      # schema + roles/permissions + e-mail templates + settings + demo data (local only)
php artisan serve               # http://localhost:8000
php artisan queue:work          # second terminal: every e-mail is sent from the queue
php artisan schedule:work       # optional: nightly expiry, integrity check and reminders
```

A database created from an earlier schema is rebuilt with `php artisan migrate:fresh --seed`
([DATABASE.md](DATABASE.md#installing-the-schema)).

> **Zero-dependency mode:** set `DB_CONNECTION=sqlite`, `SESSION_DRIVER=database`, `CACHE_STORE=database`,
> `QUEUE_CONNECTION=sync` and create `database/database.sqlite` to run without MySQL/Redis.
> Row locks are no-ops on SQLite — use MySQL for anything involving money or concurrency.

## 3. Web app (Next.js)

```bash
cd dashboard
cp .env.example .env.local      # BACKEND_INTERNAL_URL=http://localhost:8000
npm install
npm run dev                     # http://localhost:3000
```

The dev server forwards `/api/*` and `/sanctum/*` to Laravel, so the browser talks to a single origin and Sanctum
session cookies work exactly as on a server. Scanning QR codes in the web till needs a camera and a secure page
(`https://…` or `http://localhost`).

## 4. First platform administrator (servers)

Demo data is never seeded in production. Create the operator account interactively:

```bash
php artisan platform:create-admin you@company.com --name="Your Name"
```

First open **System settings → E-mail delivery**: it shows the mailer and SMTP server in use. Press **Send test
e-mail** (to your own address by default, or any mailbox you enter). A red banner on the platform pages means
e-mails are only written to the log (`MAIL_MAILER=log`).

Then open **Restaurants → Onboard restaurant**; the owner receives a welcome e-mail with a link to set their
password (valid 72 hours). The list shows each owner's invitation state (pending, expired, not delivered). If the
link expired or the address was mistyped: **⋯ → Invite again** (the address can be corrected there).

## 5. First restaurant

When the owner signs in for the first time, the dashboard shows a **Welcome** panel with four steps, each linking
to the right page:

1. **Check your voucher rules** (Settings → Vouchers): values, limits, validity, reloads, partial redemption,
   customer e-mails.
2. **Invite your team** (Team): managers and waiters receive their own 72-hour invitation.
3. **Sell the first voucher** (Vouchers → Sell voucher): record the payment and print the QR.
4. **Install the waiter app**: waiters sign in to GiftCard Waiter on the restaurant phones (or use **Redeem** in
   the browser).

For staff training use the one-page [user guide](USER_GUIDE.md); for the first day use the
[pilot checklist](PILOT_CHECKLIST.md).

## Running the tests

```bash
cd backend && php artisan test          # SQLite in memory
cd dashboard && npm run lint && npm run typecheck && npm test && npm run build
```

To run the suite against MySQL, see [DEVELOPMENT.md](DEVELOPMENT.md#testing-against-mysql).
