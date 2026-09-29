# GiftCard Pro

**Vouchers for restaurants.** A multi-tenant SaaS in which every restaurant sells, redeems and tracks its own
vouchers — with a dashboard for owners and managers and a one-handed waiter app for Android and iPhone.

```
Scan QR  →  proof of presence (60 s)  →  enter amount  →  Redeem  →  Done
```

| | |
|---|---|
| **Backend** | Laravel 12 · PHP 8.4 · MySQL 8.4 · Redis · queues · Sanctum |
| **Dashboard (web app)** | Next.js 15 (App Router) · TypeScript (strict) · Tailwind CSS 4 · shadcn/ui · React Query · React Hook Form · Zod |
| **Waiter app** | Native Android + iPhone app **GiftCard Waiter** 2.0.0 (Flutter 3.47) · camera QR scanning · device-bound sign-in · printing · [waiter-app/](waiter-app/README.md) |
| **Infrastructure** | Coolify (Docker Compose, built from source, automatic HTTPS) · Caddy gateway · GitHub Actions CI and TestFlight upload · Hetzner Cloud |
| **Tests** | PHPUnit on SQLite and MySQL incl. an abuse suite · Larastan level 8 · Flutter unit, component, screen and journey tests · browser acceptance test of a restaurant's first day with an axe accessibility scan, and an API test of the waiter app ([e2e/](e2e/README.md)) |

## Highlights

- **No spending without proof of presence.** Every redemption consumes a *presentment*: a single-use proof, valid
  60 seconds, that the voucher's QR was scanned by this waiter on this device. A voucher number is never a
  credential.
- **Vouchers carry a secret, not a number.** A printable voucher's QR holds a 256-bit random secret; the server
  stores only its hash and shows the payload once, at the sale. The printed sheet shows no voucher number and no
  value.
- **Immutable, verifiable money history.** Ledger, payments and audit log are append-only (database triggers) and
  hash-chained per restaurant; a nightly job recomputes every chain and every balance.
- **Double-spend proof.** Every balance change runs in one DB transaction under `SELECT … FOR UPDATE`, with mandatory
  idempotency keys re-checked after the lock. A till whose answer was lost asks for the outcome instead of charging
  again.
- **Every sale is paid.** Each sale and reload records its payment (cash, card terminal, bank transfer, or
  complimentary with an owner's reason).
- **Fair to guests.** No default expiry; an expired voucher keeps its balance and can be reinstated.
- **Complete tenant isolation.** Every restaurant-owned row carries `restaurant_id`; a global Eloquent scope,
  write guards, scoped route-model binding and permission gates make cross-restaurant access impossible.

## Quick start (local)

Complete, step-by-step instructions (SQLite without Docker, phones, releases): [RUNNING_THE_PROJECT.md](RUNNING_THE_PROJECT.md).

```bash
# 1. services
docker compose -f docker-compose.dev.yml up -d        # MySQL, Redis, Mailpit

# 2. API
cd backend
cp .env.example .env && composer install && php artisan key:generate
# edit .env: DB_PASSWORD=secret and REDIS_CLIENT=predis
php artisan migrate --seed                             # includes the demo restaurants
php artisan serve                                      # http://localhost:8000

# 3. Web app
cd ../dashboard
cp .env.example .env.local && npm install
npm run dev                                            # http://localhost:3000
```

A database created from an earlier schema is rebuilt with `php artisan migrate:fresh --seed`.

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
| `waiter@bellavista.test` | Waiter |
| `owner@goldenerhirsch.test` | Owner of a second restaurant (isolation demo) |

## Start here

| Document | |
|---|---|
| [RUNNING_THE_PROJECT.md](RUNNING_THE_PROJECT.md) | **How to install, start, test and release every part** — from a clean machine |
| [QUICK_COMMANDS.md](QUICK_COMMANDS.md) | Cheat sheet of all common commands |
| [CURRENT_VERSION.md](CURRENT_VERSION.md) | Current version of every part, production status, where the builds are |
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | Every folder: what it is, source or generated, in Git or not, safe to delete or not |

## Documentation

| Topic | |
|---|---|
| [Installation](docs/INSTALLATION.md) | Local setup, first platform admin, first restaurant |
| [User guide](docs/USER_GUIDE.md) | One page each for waiter, manager, owner — for staff training |
| [Pilot checklist](docs/PILOT_CHECKLIST.md) | Everything to tick before and during the first restaurant's first days |
| [Environment variables](docs/ENVIRONMENT.md) | Every variable of API, dashboard and waiter app |
| [Docker](docs/DOCKER.md) | Images, compose stack, operations |
| [Deployment](docs/DEPLOYMENT.md) | Coolify setup, backups, updates, troubleshooting |
| [Architecture](docs/ARCHITECTURE.md) | Layers, tenancy, presentments, money flow, clients |
| [Folder structure (code)](docs/FOLDER_STRUCTURE.md) | File-level map of the code |
| [Database schema](docs/DATABASE.md) | Tables, keys, triggers, hash chains, invariants |
| [API reference](docs/API.md) | Authentication, endpoints, errors, examples |
| [Security](docs/SECURITY.md) | Threat model and every control |
| [NFC](docs/NFC.md) | Physical cards (NTAG 424 DNA with live authentication): what exists and where the design is |
| [Waiter app](waiter-app/README.md) | Build, configure, sign and test GiftCard Waiter |
| [Mobile release](docs/MOBILE_RELEASE.md) | Store builds, Google Play, TestFlight pipeline and its secrets, release checklist |
| [v2 architecture](docs/architecture/giftcard-pro-v2-architecture.md) · [Implementation plan](docs/implementation/v2-implementation-plan.md) | Target architecture (ADRs) and the phases that build it |
| [Reports](docs/reports/) | Dated audit reports (historical) |
| [Waiter app design spec](docs/design/waiter-app/README.md) | Screens, design system, motion, accessibility, Flutter handoff |
| [Development guide](docs/DEVELOPMENT.md) | Conventions, tests, CI, adding features |
| [Changelog](CHANGELOG.md) | What changed in each release and why |
