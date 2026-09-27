# Project structure

`GiftCardPro/` is the one canonical project folder. Everything about GiftCard Pro — code, documentation, release
builds and signing keys — lives here, and nowhere else.

```
GiftCardPro/
├── backend/            Laravel API (PHP)                                  source
├── dashboard/          Next.js web app: dashboard, admin, web waiter, guest page   source
├── waiter-app/         GiftCard Waiter, native Android + iPhone app (Flutter)      source
├── nfc/                Signpost: where the NFC code, tests and guides are          docs only
├── docs/               All documentation (technical, business, design, reports)    source
├── e2e/                Browser and API acceptance tests                           source
├── infra/              Server config: Caddy, PHP-FPM, deploy + backup scripts      source
├── scripts/            Project scripts: collect a release, verify this structure   source
├── assets/             Store listing images                                       source
├── releases/           Release outputs (APK, AAB, symbols, source snapshots)       generated · NOT in Git
│   ├── 1.4.1/          current release
│   ├── previous/       older releases (1.4.0, 1.3.0)
│   └── latest -> 1.4.1
├── signing/            Android upload key + passwords                             SECRET · NOT in Git
├── .github/workflows/  CI (tests, builds) and deployment
├── README.md                 product overview
├── PROJECT_STRUCTURE.md      this file
├── CURRENT_VERSION.md        which version is current, where its builds are
├── RUNNING_THE_PROJECT.md    how to install, run, test and release everything
├── QUICK_COMMANDS.md         cheat sheet
├── CHANGELOG.md              every change with its reason
├── docker-compose.yml        production stack (Caddy, web, api, queue, scheduler, MySQL, Redis, backup)
├── docker-compose.dev.yml    local services (MySQL, Redis, Mailpit)
└── .env.production.example   template for the server's compose variables
```

There is **no customer app**. Guests use the web page a card opens (`https://<domain>/c/<token>`), which is part of
`dashboard/` (`dashboard/src/app/c/[token]`). There is **no separate NFC program** either: tags are programmed in the
dashboard — see [nfc/README.md](nfc/README.md).

## Legend

| Column | Meaning |
|---|---|
| **Type** | *Source* = written by people, the truth. *Generated* = made by a tool from source; can always be made again. *Local* = belongs to one machine (settings, caches). *Secret* = keys and passwords. |
| **Git** | Whether it belongs in the Git repository. |
| **Delete?** | *No* = you would lose work. *Yes* = safe, the command in brackets recreates it. *Careful* = recreatable, but only with effort or with consequences. |

## Top level

| Folder / file | Contains | Type | Git | Delete? |
|---|---|---|---|---|
| `backend/` | Laravel 12 API: business logic, database schema, e-mails, tests | Source | Yes | No |
| `dashboard/` | Next.js 15 web app: owner/manager dashboard, platform admin, NFC programming station, web waiter terminal (`/waiter`), guest balance page (`/c/<token>`), print layout | Source | Yes | No |
| `waiter-app/` | GiftCard Waiter (Flutter): Android + iOS app for waiters | Source | Yes | No |
| `nfc/` | One README pointing to the NFC code in dashboard, backend and waiter app | Source (docs) | Yes | Yes, but keep it: it is the map |
| `docs/` | All documentation (below) | Source | Yes | No |
| `e2e/` | Acceptance tests: `pilot-journey.mjs` (browser), `waiter-api.mjs` (API of the native app), `nfc-programming.mjs` (simulated NFC) | Source | Yes | No |
| `infra/` | `caddy/Caddyfile`, `docker/php/` (PHP config + entrypoint), `scripts/deploy.sh`, `scripts/backup.sh` | Source | Yes | No |
| `scripts/` | `collect-release.sh` (files a finished release into `releases/`), `verify-structure.sh` (checks this layout) | Source | Yes | No |
| `assets/` | `store/`: Play and App Store icons (see [assets/README.md](assets/README.md)) | Source | Yes | No (re-exportable from the app icon) |
| `releases/` | Built apps, symbols, source snapshots per version (below) | Generated | **No** (too large, binary) — back it up instead | **Careful**: builds can be remade, but the uploaded AAB/IPA and its symbols belong together; keep at least the current and the previous release |
| `signing/` | `giftcard-waiter-upload.jks` (Android upload key), `ANDROID_SIGNING.md` (passwords, fingerprints), `upload_certificate.pem` | **Secret** | **Never** | **No** — without the key no Play updates until Google resets it. Keep a copy in your password manager. |
| `.github/workflows/` | `ci.yml` (all tests + builds on every push), `deploy.yml` (images + deploy on tag `v*`) | Source | Yes | No |
| `README.md`, `PROJECT_STRUCTURE.md`, `CURRENT_VERSION.md`, `RUNNING_THE_PROJECT.md`, `QUICK_COMMANDS.md`, `CHANGELOG.md` | Project documentation | Source | Yes | No |
| `docker-compose.yml`, `docker-compose.dev.yml`, `.env.production.example`, `.env.staging.example`, `.gitignore`, `.dockerignore`, `.editorconfig` | Stack and tool configuration | Source | Yes | No |
| `.env.production` | Real production compose variables (only on the server) | Secret | Never | No (on the server) |

## backend/

| Path | Contains | Type | Git | Delete? |
|---|---|---|---|---|
| `app/` | Models, services, controllers, requests, resources, jobs, commands | Source | Yes | No |
| `database/migrations/` | Database schema, one file per change | Source | Yes | No — never edit an applied migration, add a new one |
| `database/seeders/`, `database/factories/` | Roles, templates, settings, demo data; test factories | Source | Yes | No |
| `routes/`, `config/`, `bootstrap/`, `resources/`, `public/` | Routes, configuration, app bootstrap, e-mail views, web root | Source | Yes | No |
| `tests/` | PHPUnit unit + feature tests | Source | Yes | No |
| `composer.json`, `composer.lock`, `phpunit.xml`, `phpstan.neon`, `pint.json`, `Dockerfile` | Dependencies and tool config | Source | Yes | No |
| `.env.example`, `.env.staging.example`, `.env.production.example` | Templates for development, staging and production ([docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)) | Source | Yes | No |
| `.env` | Your local configuration (database password, `APP_KEY`) | Local / Secret | Never | Careful (`cp .env.example .env && php artisan key:generate`; local logins stop working) |
| `vendor/` | PHP packages | Generated | Never | Yes (`composer install`) |
| `database/database.sqlite` | Local SQLite database (zero-dependency mode) | Local | Never | Yes, loses local data (`touch` + `php artisan migrate --seed`) |
| `storage/logs/`, `storage/framework/` | Logs, cache, sessions, compiled views | Generated | Never | Yes |
| `.phpunit.result.cache` | Test runner cache | Generated | Never | Yes |

## dashboard/

| Path | Contains | Type | Git | Delete? |
|---|---|---|---|---|
| `src/app/` | Pages (routes): `(app)/` dashboard + admin, `(auth)/` login, `waiter/` web terminal, `c/[token]` guest page, `print/` | Source | Yes | No |
| `src/components/`, `src/hooks/`, `src/lib/` | UI components, hooks, API client, NFC programming logic (`lib/nfc*.ts`) + unit tests (`*.test.ts`) | Source | Yes | No |
| `public/` | Static files | Source | Yes | No |
| `package.json`, `package-lock.json`, `next.config.ts`, `tsconfig.json`, `eslint.config.mjs`, `Dockerfile`, … | Dependencies and tool config | Source | Yes | No |
| `.env.example` | Template (`BACKEND_INTERNAL_URL` for local development) | Source | Yes | No |
| `.env.local` | Your local configuration | Local | Never | Yes (`cp .env.example .env.local`) |
| `node_modules/` | npm packages | Generated | Never | Yes (`npm install`) |
| `.next/`, `tsconfig.tsbuildinfo` | Build output and caches | Generated | Never | Yes (`npm run build`) |

## waiter-app/

| Path | Contains | Type | Git | Delete? |
|---|---|---|---|---|
| `lib/` | Dart app code (screens, components, API, state, platform channels) | Source | Yes | No |
| `android/`, `ios/` | Native projects: Kotlin/Swift NFC, haptics, manifest, entitlements, icons, splash | Source | Yes | No |
| `test/` | 601 Flutter tests | Source | Yes | No |
| `assets/`, `tokens/`, `l10n.yaml`, `lib/l10n/` | Fonts, icons, illustrations, design tokens, translations (DE/EN/BHS) | Source | Yes | No |
| `config/` | `development.json`, `staging.json`, `production.json`: server address, card domains, environment of each build ([waiter-app/config/README.md](waiter-app/config/README.md)) | Source | Yes | No |
| `config/*.local.json` | Your own addresses (e.g. your Mac's LAN IP) | Local | Never | Yes |
| `tool/` | `release.sh` (builds for an environment), generators for tokens, strings, icons, sounds; `brand/` icon sources | Source | Yes | No |
| `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` | Version (`1.4.2+2`), dependencies, lints | Source | Yes | No |
| `android/key.properties` | Path + passwords of the upload key (points to `../../signing/`) | Secret | Never | Careful (recreate from `signing/ANDROID_SIGNING.md`) |
| `android/local.properties` | Android SDK / Flutter path of this machine | Local | Never | Yes (Flutter recreates it) |
| `ios/Flutter/Generated.xcconfig`, `ios/Flutter/flutter_export_environment.sh`, `ios/Flutter/ephemeral/` | Flutter build settings incl. the dart-defines of the last build | Generated | Never | Yes (`flutter pub get` / `tool/release.sh ios`) |
| `ios/Flutter/Team.xcconfig` | Your Apple Team ID for scripted builds | Local | Never | Yes (`tool/release.sh ios-ipa` writes it) |
| `ios/Flutter/Environment.xcconfig` | App-link host (`CARD_DOMAIN`) of the environment last built | Generated | Never | Yes (`tool/release.sh ios …` writes it) |
| `ios/Pods/`, `ios/Podfile.lock`* | CocoaPods | Generated | Pods: never | Yes (`pod install`, run by Flutter) |
| `build/` | Flutter/Gradle build output, test caches (several GB); `build/dist/` holds the finished `giftcard-waiter-<environment>-<version>.apk/.aab` + symbols of each `tool/release.sh` run | Generated | Never | Yes — but first run `scripts/collect-release.sh` if it holds a production build you shipped |
| `.dart_tool/`, `.flutter-plugins-dependencies`, `.idea/`, `*.iml` | Tool caches, IDE files | Generated / Local | Never | Yes |

\* `ios/Podfile.lock` does not exist yet; it appears on the first Mac build and should then be committed.

## docs/

| Path | Contains | Type | Git | Delete? |
|---|---|---|---|---|
| `*.md` (top level) | Technical docs in English: `ARCHITECTURE`, `API`, `DATABASE`, `ENVIRONMENT`, `INSTALLATION`, `DEVELOPMENT`, `DOCKER`, `DEPLOYMENT`, `SECURITY`, `NFC`, `NFC-RELEASE-TEST`, `MOBILE_RELEASE`, `PILOT_CHECKLIST`, `USER_GUIDE`, `FOLDER_STRUCTURE` (file-level map of the code) | Source | Yes | No |
| `de/`, `bhs/` | Business, product, sales, marketing, customer-success, technical, security, legal and brand documents; German master + BHS translation with identical file names | Source | Yes | No |
| `design/waiter-app/` | Locked design specification of the waiter app (15 documents) | Source | Yes | No |
| `reports/` | Dated audit reports: implementation audit, NFC audit (before 1.4.0), NFC final pass (1.4.1). Historical, not updated | Source | Yes | No |
| `screenshots/` | Screenshots used by `README.md` | Source | Yes | No |

## releases/

One folder per version, **one canonical copy of each release**. `latest` is a symbolic link to the current one;
older releases move to `previous/` (done by `scripts/collect-release.sh`).

```
releases/
├── 1.4.1/                              ← CURRENT (latest)
│   ├── RELEASE.md                      what is in this release
│   ├── SHA256SUMS                      checksums of every file
│   ├── android/app-release.apk         for test phones
│   ├── android/app-release.aab         for Google Play
│   ├── android/dart-symbols-android-1.4.1+1.zip
│   ├── android/r8-mapping-1.4.1+1.txt.gz
│   ├── ios/README.txt                  (iOS builds go from Xcode straight to TestFlight)
│   └── source/giftcard-pro-1.4.1-source.zip
├── previous/
│   ├── 1.4.0/source/giftcard-pro-1.4.0-source.zip
│   └── 1.3.0/source/giftcard-pro-1.3.0-source.zip
└── latest -> 1.4.1
```

Source snapshots of 1.4.1 and older were made before this reorganisation: inside them the web app is in
`frontend/` (now `dashboard/`).

## What was cleaned up (27 September 2026)

| Before | Now |
|---|---|
| `giftcard-pro/`, `giftcard-pro 2/`, `giftcard-pro 3/` (three partial copies) | `GiftCardPro/` (all three were older states; nothing unique in them) |
| `frontend/` | `dashboard/` (folder renamed; CI paths and docs updated, no code changed) |
| `giftcard-pro.zip` | `releases/previous/1.3.0/source/` |
| `giftcard-pro-1.4.0.zip` | `releases/previous/1.4.0/source/` |
| `giftcard-pro-1.4.1.zip` (1.4.1 before the store builds) | removed — superseded by `releases/1.4.1/source/` |
| `giftcard-pro-docs.zip` | removed — older copy of `docs/` |
| `giftcard-waiter-design.zip` | removed — identical to `docs/design/` |
| `implementation-audit.md`, `nfc-audit.md` | `docs/reports/` |
| `nfc-v2-final-pass-report.md` + `docs/NFC-FINAL-PASS-2026-09-27.md` (identical) | one copy: `docs/reports/2026-09-27-nfc-final-pass.md` |
| `releases/1.4.1/store-assets/` | `assets/store/` |
| `giftcard-pro-signing/` | `signing/` |

Check the structure at any time: `scripts/verify-structure.sh`.
