# GiftCard Pro

**NFC gift cards for restaurants.** A multi-tenant SaaS in which every restaurant issues, sells, redeems and
tracks its own NFC / QR gift cards — with an Apple-style dashboard for managers and a one-handed waiter app
that redeems a card in under five seconds.

```
Tap card  →  card opens  →  enter amount  →  Redeem  →  Done
```

| | |
|---|---|
| **Backend** | Laravel 12 · PHP 8.4 · MySQL 8.4 · Redis · queues · Sanctum |
| **Dashboard (web app)** | Next.js 15 (App Router) · TypeScript (strict) · Tailwind CSS 4 · shadcn/ui · React Query · React Hook Form · Zod |
| **Waiter app** | Native Android + iPhone app **GiftCard Waiter** (Flutter 3.47) · NFC reader mode / Core NFC · device-bound sign-in · [waiter-app/](waiter-app/README.md) |
| **Infrastructure** | Coolify (Docker Compose, built from source, automatic HTTPS) · Caddy gateway · GitHub Actions CI · Hetzner Cloud |
| **Tests** | 130 PHPUnit tests (SQLite + MySQL/MariaDB) · Larastan level 8 · 601 Flutter tests (unit, component, screen, end-to-end journey) · browser acceptance test of a pilot restaurant's first day incl. axe accessibility scan and an API test of the waiter app ([e2e/](e2e/README.md)) |

## Screenshots

| Owner dashboard | Waiter app | Card |
|---|---|---|
| ![Dashboard](docs/screenshots/owner-dashboard.png) | ![Waiter](docs/screenshots/waiter-amount.png) | ![Card detail](docs/screenshots/card-detail.png) |
| **Gift cards** | **Done in one tap** | **Guest balance page** |
| ![Gift cards](docs/screenshots/gift-cards.png) | ![Success](docs/screenshots/waiter-success.png) | ![Public page](docs/screenshots/public-balance.png) |

More in [docs/screenshots](docs/screenshots/): new card, transactions, print layout, phone, dark mode, platform admin.

## Highlights

- **Complete tenant isolation.** Every restaurant-owned row carries `restaurant_id`; a global Eloquent scope,
  write guards, scoped route-model binding and permission gates make cross-restaurant access impossible.
- **The card never stores money.** A tag holds only `https://<your-domain>/c/<random UUID v4>`. Balance,
  history and customer data live exclusively on the server.
- **Double-spend proof.** Every balance change runs in one DB transaction under `SELECT … FOR UPDATE`,
  with mandatory idempotency keys and an immutable ledger (`sum(ledger) == balance`, always).
  Verified with 20 concurrent redemptions against MariaDB: exactly the affordable number succeeded.
- **Anti-cloning.** NTAG213/215 chips are bound to their hardware UID; NTAG 424 DNA is fully supported with
  AES-CMAC **SUN** verification and replay counters (verified against NXP AN12196 test vectors).
- **Nothing is ever deleted.** Soft deletes, append-only ledger and audit trail, revocation instead of deletion,
  GDPR anonymisation instead of erasure of financial records.
- **Built for service.** Waiter app with Web NFC (Android), native NFC link handling (iPhone), camera QR
  scanning, manual entry, POS-style keypad, haptic feedback, idempotent retries.

## Quick start (local)

Complete, step-by-step instructions (SQLite without Docker, phones, NFC, releases): [RUNNING_THE_PROJECT.md](RUNNING_THE_PROJECT.md).

```bash
# 1. services
docker compose -f docker-compose.dev.yml up -d        # MySQL, Redis, Mailpit

# 2. API
cd backend
cp .env.example .env && composer install && php artisan key:generate
# edit .env: DB_PASSWORD=secret and REDIS_CLIENT=predis
php artisan migrate --seed                             # includes the demo restaurant
php artisan serve                                      # http://localhost:8000

# 3. Web app
cd ../dashboard
cp .env.example .env.local && npm install
npm run dev                                            # http://localhost:3000
```

To start from an **empty platform** instead (as in production), skip the demo data and create the operator:

```bash
php artisan migrate --force && php artisan db:seed --class='Database\Seeders\RolesAndPermissionsSeeder' \
  && php artisan db:seed --class='Database\Seeders\NotificationTemplateSeeder' && php artisan db:seed --class='Database\Seeders\SystemSettingsSeeder'
php artisan platform:create-admin you@company.com --name="Your Name"
```

Demo logins (password `Password123!`):

| E-mail | Role |
|---|---|
| `admin@giftcardpro.test` | Platform administrator |
| `owner@bellavista.test` | Owner — Trattoria Bella Vista |
| `manager@bellavista.test` | Manager |
| `waiter@bellavista.test` | Waiter (opens the waiter app) |
| `owner@goldenerhirsch.test` | Owner of a second restaurant (isolation demo) |

## Start here

| Document | |
|---|---|
| [RUNNING_THE_PROJECT.md](RUNNING_THE_PROJECT.md) | **How to install, start, test and release every part** — from a clean machine |
| [QUICK_COMMANDS.md](QUICK_COMMANDS.md) | Cheat sheet of all common commands |
| [CURRENT_VERSION.md](CURRENT_VERSION.md) | Current version of every part, production status, where the latest APK / AAB / iOS build is |
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | Every folder: what it is, source or generated, in Git or not, safe to delete or not |

## Documentation

| Topic | |
|---|---|
| [Installation](docs/INSTALLATION.md) | Local setup, first platform admin, first restaurant |
| [User guide](docs/USER_GUIDE.md) | One page each for waiter, manager, owner — for staff training |
| [Pilot checklist](docs/PILOT_CHECKLIST.md) | Everything to tick before and during the first restaurant's go-live |
| [Environment variables](docs/ENVIRONMENT.md) | Every variable of API and web app |
| [Docker](docs/DOCKER.md) | Images, compose stack, operations |
| [Deployment](docs/DEPLOYMENT.md) | Hetzner server setup, CI/CD, backups, updates |
| [Architecture](docs/ARCHITECTURE.md) | Layers, tenancy, money flow, web app structure |
| [Folder structure (code)](docs/FOLDER_STRUCTURE.md) | File-level map of the code |
| [Database schema](docs/DATABASE.md) | Tables, keys, invariants, ER diagram |
| [API reference](docs/API.md) | Authentication, endpoints, errors, examples |
| [Security](docs/SECURITY.md) | Threat model and every control |
| [NFC guide](docs/NFC.md) | NTAG213/215/424 DNA, writing, provisioning, clone protection |
| [Waiter app](waiter-app/README.md) | Build, configure, sign and test the native GiftCard Waiter app |
| [Mobile release](docs/MOBILE_RELEASE.md) | Store builds, Google Play and TestFlight steps, release checklist |
| [NFC release test](docs/NFC-RELEASE-TEST.md) | Real-tag test on real phones before a release |
| [Reports](docs/reports/) | Dated audit reports (implementation, NFC) |
| [Waiter app design spec](docs/design/waiter-app/README.md) | Native Android/iPhone waiter app (GiftCard Waiter): screens, design system, motion, accessibility, Flutter handoff |
| [Development guide](docs/DEVELOPMENT.md) | Conventions, tests, adding features |
| [Changelog](CHANGELOG.md) | What changed in each release and why |
