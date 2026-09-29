# Current version

> **Keep this file current.** Update it in the same change that bumps a version, deploys to production or uploads
> to a store (checklist at the end). Last updated: **29 September 2026**.

## Versions

| | Version | Where it is defined |
|---|---|---|
| Current platform version | **1.4.1** — the last packaged release (`releases/latest`) | backend, dashboard and waiter app share this number; `waiter-app/pubspec.yaml` |
| Current development release | **2.0.0** — vouchers, presentments, payments and immutable, hash-chained history (ADR-002 Phase 0) | `CHANGELOG.md` |
| Waiter app version | **2.0.0 (build 4)** — Android `versionName 2.0.0` / `versionCode 4`, iOS `2.0.0` / `4` for local builds; TestFlight builds from CI use build `1000 + run number` | `waiter-app/pubspec.yaml` → `version: 2.0.0+4` |
| Backend version | **2.0.0** (Laravel 12, PHP 8.4) | platform version; the backend has no own version number |
| Dashboard version | **2.0.0** | platform version (`dashboard/package.json` says `1.0.0` — that field is not maintained) |
| Database schema | **7 migrations**, newest `2026_01_01_000007_make_financial_history_append_only` | `backend/database/migrations/`; check a database with `php artisan migrate:status`. A database created from an earlier schema is rebuilt with `php artisan migrate:fresh --seed` |
| API version | **v1** (`/api/v1`) | `backend/routes/api.php`; reference: [docs/API.md](docs/API.md) |
| Customer app | **— (there is no customer app)** | guests keep a printed voucher with a QR code |

## Environments of the waiter app

| Environment | Config file | Server | Status |
|---|---|---|---|
| development | `waiter-app/config/development.json` | your computer (`http://10.0.2.2:8000/api/v1` from the emulator; your own IP in `development.local.json`) | works |
| staging | `waiter-app/config/staging.json` | — | **no staging server yet** (file has an empty address) |
| production | `waiter-app/config/production.json` | `https://app.giftcardpro.at/api/v1` | **domain not registered, server not deployed** — production builds show *Server not found* |

## Releases

| | |
|---|---|
| **Current production release** | **None live.** No production server exists (`giftcardpro.at` is not registered) and nothing is in a store. Go-live steps (Coolify): [docs/DEPLOYMENT.md → First deployment](docs/DEPLOYMENT.md#first-deployment--step-by-step). When it goes live, write the version, date and server here. |
| Production server | none yet — planned `https://app.giftcardpro.at` (Coolify on Hetzner, `docker-compose.coolify.yml`) |
| Google Play | not uploaded |
| App Store / TestFlight | not uploaded. `.github/workflows/testflight.yml` uploads every merge to `main` that changes the app once the secrets `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID` and `APP_STORE_CONNECT_KEY_P8` are set ([docs/MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md#testflight-from-ci)) |
| Latest filed release | **1.4.1**, 27 September 2026 — `releases/1.4.1/` (= `releases/latest`). It was built before 2.0.0, uses endpoints the API no longer has and must not be distributed. |

## Where the builds are

| Build | Location |
|---|---|
| 2.0.0 Android APK / AAB | not filed yet: `cd waiter-app && tool/release.sh android production`, then `scripts/collect-release.sh` → `releases/2.0.0/` |
| Development / test builds | `waiter-app/build/dist/giftcard-waiter-<environment>-<version>.apk` / `.aab` after `tool/release.sh android <environment>` (not kept in `releases/`) |
| iOS builds | TestFlight, uploaded by CI (App Store Connect keeps them); the Dart symbols of each CI build are a workflow artifact `dart-symbols-<run number>`. A scripted local `.ipa` (`tool/release.sh ios-ipa production`) is filed under `releases/<version>/ios/` |
| Unsigned iOS build | built by CI (`ci.yml`, job *Waiter app iOS build*) on every push and pull request; not kept |
| Signing key | Android upload key in `signing/` (never committed); iOS signing through the App Store Connect API key in GitHub secrets |

## Short summary of 2.0.0

- **Vouchers** (`/vouchers`): kind `card` or `digital`, statuses `active`, `blocked`, `expired`; the voucher number
  is internal. Digital vouchers are sold with a printable QR (256-bit secret, shown once).
- **Presentments**: every redemption consumes a single-use, 60-second proof of presence bound to user, device,
  restaurant and voucher. Unknown outcomes are resolved with `GET /vouchers/{id}/redemptions/{key}`.
- **Payments** for every sale and reload; complimentary only for owners, with a reason.
- **Immutable history**: ledger, payments and audit log append-only (database triggers) and hash-chained;
  `giftcard:verify-chains` nightly. No default expiry; expiry keeps the balance.
- **Security findings closed**: remembered sign-in bound to the device, no tokens for platform administrators,
  password reset revokes every token, uniform sign-in and reset answers, separate invitation tokens, lockouts per
  user and device, queued mail, gateway log redaction, php-fpm request limit.
- **Waiter app 2.0.0**: QR scanning only, pending-attempt store for unknown outcomes, *Sell voucher* with printing on
  Android and iPhone; tokens limited by method and path.
- **Removed**: NFC tag programming and reading, NTAG21x, `POST /scan`, `/cards/*`, the public card page, card links
  and app-link files, transfers and replacement, redemption by typed number.

Full history with reasons: [CHANGELOG.md](CHANGELOG.md). Implementation status per story:
[docs/implementation/v2-implementation-plan.md → Phase 0](docs/implementation/v2-implementation-plan.md#3-phase-0-security-foundation).

## Open before the first production release

- Register `giftcardpro.at`, deploy the server on Coolify ([docs/DEPLOYMENT.md → First deployment](docs/DEPLOYMENT.md#first-deployment--step-by-step)).
- Set the four App Store Connect secrets so TestFlight builds are uploaded.
- Build and file 2.0.0 for Android: `tool/release.sh android production` → `scripts/collect-release.sh`.
- Waiter app checks on real phones ([docs/MOBILE_RELEASE.md → Release checklist](docs/MOBILE_RELEASE.md#release-checklist)).

## Updating this file

1. **New version:** bump `waiter-app/pubspec.yaml` (the build number always goes up), add a `CHANGELOG.md`
   section, then update *Versions*.
2. **After the production build:** `scripts/collect-release.sh` → update *Latest filed release* and *Where the builds are*.
3. **After deploying / uploading:** fill in *Current production release*, *Google Play*, *App Store*.
4. **New migration:** update *Database schema*.
5. Run `scripts/verify-structure.sh` — it compares this file, `pubspec.yaml`, `CHANGELOG.md` and `releases/latest`.
