# Current version

> **Keep this file current.** Update it in the same change that bumps a version, deploys to production or uploads
> to a store (checklist at the end). Last updated: **27 September 2026**.

## Versions

| | Version | Where it is defined |
|---|---|---|
| Current platform version | **1.4.1** (latest release) · **1.4.2** in development | `CHANGELOG.md` — backend, dashboard and waiter app share this number |
| Current app version | **1.4.2 (build 2)**, not released yet | `waiter-app/pubspec.yaml` → `version: 1.4.2+2` |
| Backend version | **1.4.1** (Laravel 12, PHP 8.4) — unchanged in 1.4.2 | platform version; the backend has no own version number |
| Database migration version | **`2026_10_02_000001_add_nfc_attempt_timings`** (10 migrations) | newest file in `backend/database/migrations/`; check a database with `php artisan migrate:status` |
| API version | **v1** (`/api/v1`) | `backend/routes/api.php`; unchanged since 1.0 |
| Dashboard version | **1.4.1** — unchanged in 1.4.2 | platform version (`dashboard/package.json` says `1.0.0` — that field is not maintained) |
| Waiter app version | **1.4.2 (build 2)** in development — Android `versionName 1.4.2` / `versionCode 2`, iOS `1.4.2` / `2`. Last release: 1.4.1 (build 1), **defective** (see below) | `waiter-app/pubspec.yaml` |
| Customer app version | **— (there is no customer app)** | guests use the web page `/c/<token>` in the dashboard |

## Environments of the waiter app

| Environment | Config file | Server | Status |
|---|---|---|---|
| development | `waiter-app/config/development.json` | your computer (`http://10.0.2.2:8000/api/v1` from the emulator; your own IP in `development.local.json`) | works |
| staging | `waiter-app/config/staging.json` | — | **no staging server yet** (file has an empty address) |
| production | `waiter-app/config/production.json` | `https://app.giftcardpro.at/api/v1` | **domain not registered, server not deployed** — production builds show *Server not found* |

## Releases

| | |
|---|---|
| **Current production release** | **None live.** No production server exists (`giftcardpro.at` is not registered; DNS answers NXDOMAIN) and nothing is uploaded to a store. Go-live steps: [docs/DEPLOYMENT.md → Go-live](docs/DEPLOYMENT.md#go-live-first-deployment-of-giftcardproat). When it goes live, write the version, date and server here. |
| Production server | none yet — planned `https://app.giftcardpro.at` (Hetzner) |
| Google Play | not uploaded |
| App Store / TestFlight | not uploaded (needs a Mac: `waiter-app/tool/release.sh ios production`) |
| **Current development release** | **1.4.2** (in development, not released) — environments for the waiter app and the fix for the launch-screen hang. |
| Latest release | **1.4.1**, 27 September 2026 — `releases/1.4.1/` (= `releases/latest`) |

### Known defect of the 1.4.1 waiter app — do not distribute

The 1.4.1 APK/AAB in `releases/1.4.1/android/` **never leaves the launch screen on any Android phone with a screen
lock** (PIN, pattern, fingerprint), whatever the network. Cause: its secure-storage setting created a Keystore key
that requires a fingerprint for every use; the first storage access during start-up threw an exception before the
first frame was drawn. Reproduced on an Android 9 emulator with a PIN; fixed in 1.4.2 (details in `CHANGELOG.md`).
Independently, it points at `https://app.giftcardpro.at/api/v1`, which does not exist yet.

## Where the builds are

| Build | Location |
|---|---|
| Latest Android APK (release) | `releases/latest/android/app-release.apk` (→ 1.4.1, **defective**, see above) |
| Latest Android AAB (release) | `releases/latest/android/app-release.aab` (→ 1.4.1, **defective**) |
| Development / test builds | `waiter-app/build/dist/giftcard-waiter-<environment>-<version>.apk` / `.aab` after `tool/release.sh android <environment>` (not kept in `releases/`) |
| Latest iOS build | **none yet.** iOS builds are made on a Mac and uploaded from Xcode to TestFlight; App Store Connect keeps them. A scripted `.ipa` (`tool/release.sh ios-ipa production`) is filed under `releases/<version>/ios/`. |
| Crash symbols | `releases/1.4.1/android/dart-symbols-android-1.4.1+1.zip`, `releases/1.4.1/android/r8-mapping-1.4.1+1.txt.gz` |
| Source snapshot | `releases/1.4.1/source/giftcard-pro-1.4.1-source.zip` |
| Signing key used | Android upload key `signing/giftcard-waiter-upload.jks` (SHA-256 `26:CE:FB:16:…:E4:94`) |

## Short changelog

**1.4.2 — in development**
- Waiter app environments: development / staging / production from `waiter-app/config/*.json`; no server address
  in the code; dev/staging builds install next to the store app and can switch server in the app.
- Startup problem screen instead of an endless splash: the reason (no internet, server not found, not running,
  no answer, certificate, server error, wrong address, invalid configuration, storage) with *Try again*.
- Fix: the app hung on the launch screen on every phone with a screen lock (secure-storage setting).

**1.4.1 — 27 September 2026**
- Store builds of GiftCard Waiter (signed APK + AAB, target SDK 36, backup exclusion, iOS privacy manifest).
- NFC programming final pass (station statistics, error classes, timeouts, multi-phone protection).

**1.4.0** — NFC programming v2 in the dashboard. **1.3.0** — Native waiter app GiftCard Waiter.

Full history with reasons: [CHANGELOG.md](CHANGELOG.md).

## Open before the first production release

- Register `giftcardpro.at`, deploy the server ([docs/DEPLOYMENT.md → Go-live](docs/DEPLOYMENT.md#go-live-first-deployment-of-giftcardproat)).
- Build and file 1.4.2: `tool/release.sh android production` → `scripts/collect-release.sh`.
- Real-tag NFC release test on two Android phones ([docs/NFC-RELEASE-TEST.md](docs/NFC-RELEASE-TEST.md)).
- First iOS build on a Mac; waiter app checks on real phones.
- Server variables `WAITER_ANDROID_CERT_SHA256` (upload + Play app-signing key) and `WAITER_IOS_APP_IDS`.

## Updating this file

1. **New version:** bump `waiter-app/pubspec.yaml` (`1.4.3+3` — the build number always goes up), add a
   `CHANGELOG.md` section, then update *Versions* and *Current development release*.
2. **After the production build:** `scripts/collect-release.sh` → update *Latest release* and *Where the builds are*.
3. **After deploying / uploading:** fill in *Current production release*, *Google Play*, *App Store*.
4. **New migration:** update *Database migration version*.
5. Run `scripts/verify-structure.sh` — it fails if this file, `pubspec.yaml`, `CHANGELOG.md` and `releases/latest` disagree.
