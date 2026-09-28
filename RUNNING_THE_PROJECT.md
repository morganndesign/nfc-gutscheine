# Running the project

The one place that explains how to install, start, test and release every part of GiftCard Pro, starting from a
clean machine. All commands are run from the project folder `GiftCardPro/` unless a `cd` says otherwise.
Short version of every command: [QUICK_COMMANDS.md](QUICK_COMMANDS.md). Folder map: [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md).

| Component | Folder | Start (development) | Runs at |
|---|---|---|---|
| Backend (API) | `backend/` | `cd backend && php artisan serve` | http://localhost:8000 |
| Dashboard (web app) | `dashboard/` | `cd dashboard && npm run dev` | http://localhost:3000 |
| Waiter app | `waiter-app/` | `cd waiter-app && flutter run --dart-define-from-file=config/development.json` | emulator / phone (section 3.0: environments) |
| Customer app | — | does not exist; guests use `http://localhost:3000/c/<token>` (part of the dashboard) | |
| NFC programming | in `dashboard/` | dashboard on an Android phone in Chrome → *Gift cards → Program NFC tags* | phone |
| Local services (optional) | `docker-compose.dev.yml` | `docker compose -f docker-compose.dev.yml up -d` | MySQL :3306, Redis :6379, Mailpit http://localhost:8025 |

Start order: (services) → backend → dashboard → waiter app. Sign in with the demo logins (password `Password123!`):
`admin@giftcardpro.test` (platform admin), `owner@bellavista.test`, `manager@bellavista.test`,
`waiter@bellavista.test`, `owner@goldenerhirsch.test` (second restaurant).

---

## 0. Clean machine (macOS)

The instructions use macOS with [Homebrew](https://brew.sh) (Linux: use the distribution's packages; the
commands after installation are the same).

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install php@8.4 composer node@22 git
brew install --cask docker            # Docker Desktop: MySQL, Redis, Mailpit for development (optional, see 1.3)
```

| Tool | Version | Needed for |
|---|---|---|
| PHP | 8.4 with `intl`, `pdo_mysql`, `pdo_sqlite`, `mbstring`, `gd`, `zip`, `bcmath` (Homebrew's PHP has all of them) | backend |
| Composer | 2.x | backend |
| Node.js | 22 LTS (+ npm 10) | dashboard, e2e tests |
| Docker Desktop | 24+ | local MySQL/Redis/Mailpit (optional), production images |
| Flutter | **3.47.5** stable (Dart 3.x included) | waiter app |
| Android Studio | current, with Android SDK 36, SDK command-line tools, an emulator image; JDK 21 (bundled) | Android builds |
| Xcode | current, + CocoaPods (`brew install cocoapods`) | iOS builds (Mac only) |

Check: `php -v`, `composer -V`, `node -v`, `docker -v`, `flutter --version`.

---

## 1. Backend (Laravel API) — `backend/`

### 1.1 Prerequisites
PHP 8.4 and Composer 2 (section 0). A database: **SQLite** (nothing to install, good for UI work) or **MySQL 8.4**
from `docker-compose.dev.yml` (use it for anything involving money, locking or concurrency — SQLite ignores row locks).

### 1.2 Install dependencies
```bash
cd backend
composer install
```

### 1.3 Configure `.env`
```bash
cp .env.example .env
php artisan key:generate          # writes APP_KEY into .env
```
Then open `backend/.env` in an editor and choose **one** of the two setups:

**A — SQLite, no Docker (quickest):** change these lines
```
DB_CONNECTION=sqlite
# DB_DATABASE=giftcard_pro        ← comment this line out (SQLite then uses database/database.sqlite)
SESSION_DRIVER=database
CACHE_STORE=database
QUEUE_CONNECTION=sync
```
E-mails (invitations, password links) need no setting: with `MAIL_MAILER=failover` from `.env.example` they go to
Mailpit when it runs (`docker compose -f docker-compose.dev.yml up -d mailpit`, or `brew install mailpit && mailpit`;
inbox http://localhost:8025), otherwise into `storage/logs/laravel.log`.
and create the database file: `touch database/database.sqlite`

**B — MySQL + Redis + Mailpit (like production):**
```bash
docker compose -f docker-compose.dev.yml up -d      # from GiftCardPro/, not backend/
```
and in `backend/.env` set
```
DB_PASSWORD=secret
REDIS_CLIENT=predis              # no PHP redis extension needed
```
E-mails then appear in Mailpit at http://localhost:8025.

All variables are explained in [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

### 1.4 Run migrations
```bash
php artisan migrate
```

### 1.5 Seed the database
```bash
php artisan db:seed              # roles, e-mail templates, settings + demo restaurants (in APP_ENV=local)
```
Start over at any time with demo data: `php artisan migrate:fresh --seed` (**deletes all local data**).

Empty platform instead of demo data (as in production):
```bash
php artisan db:seed --class='Database\Seeders\RolesAndPermissionsSeeder'
php artisan db:seed --class='Database\Seeders\NotificationTemplateSeeder'
php artisan db:seed --class='Database\Seeders\SystemSettingsSeeder'
php artisan platform:create-admin you@example.com --name="Your Name"
```

### 1.6 Start the development server
```bash
php artisan serve                # http://localhost:8000 — check http://localhost:8000/up
php artisan queue:work           # second terminal, only with QUEUE_CONNECTION=redis (setup B): sends e-mails
php artisan schedule:work        # optional third terminal: nightly expiry and reminder jobs
```
To reach the API from a phone on the same Wi-Fi: `php artisan serve --host=0.0.0.0 --port=8000`.

### 1.7 Run the production server
Production runs on **Coolify** from this GitHub repository, never with `php artisan serve`. Coolify builds every
image from source with `docker-compose.coolify.yml` (gateway, api, migrate, worker, scheduler, web, MySQL, Redis,
backup) and provides HTTPS. Setup in short: create a *Docker Compose* resource from the repository, Compose file
`/docker-compose.coolify.yml`, give the **gateway** service the domain `https://app.giftcardpro.at`, add the mail
settings from `.env.production.example`, press *Deploy*. Migrations run automatically on every deploy. Then, in
Coolify → *Terminal* → container **api**:
```bash
php artisan platform:create-admin you@company.com
```
Staging is a second Coolify resource with its own domain and `APP_ENV=staging`. The API refuses to start in
staging/production if the public URL is missing, not https or points at a development machine. All environment
variables: [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md). Step by step, backups and troubleshooting:
[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md), images: [docs/DOCKER.md](docs/DOCKER.md).

### 1.8 Run the tests
```bash
cd backend
php artisan test                 # all PHPUnit tests, SQLite in memory (no setup needed)
php artisan test --filter=NfcProgrammingTest
vendor/bin/pint --test           # code style
vendor/bin/phpstan analyse       # static analysis (Larastan)
```
Against MySQL (as CI does): [docs/DEVELOPMENT.md → Testing against MySQL](docs/DEVELOPMENT.md#testing-against-mysql).

---

## 2. Dashboard (Next.js web app) — `dashboard/`

The dashboard is the owners'/managers' web app, the platform admin, the NFC programming station, the web waiter
terminal (`/waiter`) and the guests' balance page (`/c/<token>`). In development it forwards `/api` and `/sanctum`
to the backend, so **the backend must be running** (section 1.6).

### 2.1 Install
```bash
cd dashboard
cp .env.example .env.local       # BACKEND_INTERNAL_URL=http://localhost:8000
npm install                      # or `npm ci` for exactly the versions in package-lock.json
```

### 2.2 Start development
```bash
npm run dev                      # http://localhost:3000 → sign in with a demo login
```

### 2.3 Production build
```bash
npm run build                    # must finish without errors before every release
npm start                        # optional: run the built app locally on http://localhost:3000
```
In production the dashboard runs as the `web` Docker image built from `dashboard/Dockerfile` (section 1.7).

### 2.4 Lint
```bash
npm run lint                     # ESLint
npm run typecheck                # TypeScript
npm run format                   # Prettier (rewrites files)
```

### 2.5 Tests
```bash
npm test                         # unit tests (node --test): NFC programming, helpers
```
Browser acceptance tests: section 9.

---

## 3. Waiter app (GiftCard Waiter, Flutter) — `waiter-app/`

### 3.0 Environments — where the app connects to
The server address is **not in the code**. Every build reads it from one file in `waiter-app/config/`
([config/README.md](waiter-app/config/README.md)):

| Environment | File | Server | Installs as | http allowed | Server changeable in the app |
|---|---|---|---|---|---|
| development | `config/development.json` | `http://10.0.2.2:8000/api/v1` = your computer, seen from the Android emulator | `eu.tapredeem.waiter.dev` · *GiftCard Waiter Dev* | yes | yes |
| staging | `config/staging.json` | empty until a staging server exists | `eu.tapredeem.waiter.staging` · *GiftCard Waiter Staging* | no | yes |
| production | `config/production.json` | `https://app.giftcardpro.at/api/v1` (only works once the domain and server exist, section 11) | `eu.tapredeem.waiter` · *GiftCard Waiter* | no | no |

Switch environment = pick another file (`flutter run --dart-define-from-file=config/staging.json`,
`tool/release.sh android staging`). For your own addresses, copy a file to `<environment>.local.json` (not committed;
`tool/release.sh` prefers it). Development and staging builds show a **DEV / STAGING** ribbon in the top-right
corner: **long-press it** to type another server address — no rebuild needed (the app signs out and connects).
The three variants install side by side on one phone.

If the server cannot be reached at launch, the app shows **why** (no internet, server not found, server not running,
no answer, certificate rejected, server error, wrong address, invalid configuration) with the address it tried, the
technical detail and *Try again* — it never stays on the launch screen.

### 3.1 Install Flutter
1. Download Flutter **3.47.5** (stable) for macOS from https://docs.flutter.dev/install/archive, unpack it to
   e.g. `~/development/flutter`, and add it to the PATH (`~/.zshrc`):
   `export PATH="$HOME/development/flutter/bin:$PATH"`
2. **Android:** install Android Studio → *SDK Manager*: Android SDK Platform **36**, *Android SDK Command-line Tools*,
   *Android Emulator*. Then `flutter doctor --android-licenses` (accept all). Add `adb` to the PATH:
   `export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"`.
3. **iOS (Mac):** install Xcode from the App Store, then
   `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch`
   and `brew install cocoapods`.
4. `flutter doctor` — Flutter, Android toolchain and Xcode must show ✓.

### 3.2 Install packages
```bash
cd waiter-app
flutter pub get
flutter test                     # 626 tests, should pass before you start
flutter analyze
```

### 3.3 Android emulator
Backend on :8000 (section 1.6, plain `php artisan serve` is enough). The emulator reaches your computer as `10.0.2.2`,
which is exactly what `config/development.json` contains.
1. Android Studio → *Device Manager* → *Create device* → Pixel, system image API 36 → start it
   (or `flutter emulators` and `flutter emulators --launch <id>`).
2. Run:
```bash
cd waiter-app
flutter run --dart-define-from-file=config/development.json
```
3. Sign in as `waiter@bellavista.test` / `Password123!`. The emulator has no NFC: open cards with *Card number*
   (e.g. a number from the dashboard's gift card list) or the QR scanner (emulated camera).

### 3.4 Physical Android phone
Two ways; both use the **development** environment.

**A — USB cable, `flutter run` (for coding):** phone: *Settings → About phone* → tap *Build number* 7× →
*Developer options* → **USB debugging** on. Connect, allow the computer, `adb devices` must list it. Then:
```bash
adb reverse tcp:8000 tcp:8000              # the phone's localhost:8000 = your computer's port 8000
cd waiter-app
flutter run --dart-define-from-file=config/development.json
```
then long-press the DEV ribbon and enter `http://localhost:8000` once (the app remembers it), or copy
`config/development.json` to `config/development.local.json` with `"API_BASE_URL": "http://localhost:8000/api/v1"`
and run with that file.

**B — APK over Wi-Fi (no cable, e.g. to hand a phone to a waiter):** phone and computer in the same Wi-Fi.
1. Your computer's address: `ipconfig getifaddr en0` (e.g. `192.168.1.20`).
2. Backend reachable from the network: `cd backend && php artisan serve --host=0.0.0.0 --port=8000`
   (allow incoming connections if macOS asks). Test from the phone's browser: `http://192.168.1.20:8000/api/v1/app/config?platform=android&version=1.4.2` must show JSON.
3. In `backend/.env` set `CARD_BASE_URL=http://192.168.1.20:3000` (card links/QR codes then point at your computer).
4. `waiter-app/config/development.local.json`:
   ```json
   { "APP_ENV": "development", "API_BASE_URL": "http://192.168.1.20:8000/api/v1", "CARD_DOMAINS": "192.168.1.20,localhost" }
   ```
5. `cd waiter-app && tool/release.sh android development` →
   `waiter-app/build/dist/giftcard-waiter-development-<version>.apk`. Copy it to the phone (AirDrop is not available
   for Android: use `adb install -r <apk>`, Google Drive, or e-mail) and open it to install
   (allow "Install unknown apps" for the app you open it with).
6. Start *GiftCard Waiter Dev*, sign in as `waiter@bellavista.test`.
If your computer gets another IP later, long-press the DEV ribbon and enter the new address — no new APK needed.

### 3.5 iPhone simulator (Mac)
The simulator shares the Mac's network: `127.0.0.1` is the backend.
```bash
open -a Simulator                # pick an iPhone in File → Open Simulator
cd waiter-app
flutter run --dart-define-from-file=config/development.json
```
Then long-press the DEV ribbon → `http://127.0.0.1:8000` (once), or use a `development.local.json` with
`http://127.0.0.1:8000/api/v1`. No NFC and no camera in the simulator: use *Card number*.

### 3.6 Physical iPhone (Mac)
Needs a **paid Apple Developer account** (NFC tag reading and Associated Domains are not available to free teams).
1. iPhone: connect by cable, trust the Mac; *Settings → Privacy & Security → Developer Mode* on.
2. `open waiter-app/ios/Runner.xcworkspace` → target *Runner* → *Signing & Capabilities* → select your **Team**
   (once; Xcode registers the app id).
3. Backend reachable from the network as in 3.4 B (steps 1–3), `development.local.json` with your Mac's IP, then
```bash
cd waiter-app
flutter run --dart-define-from-file=config/development.local.json
```
On iOS all three environments use the bundle id `eu.tapredeem.waiter` (one provisioning profile); the ribbon shows
which one is installed. Opening card links from the lock screen (Universal Links) only works with the real https
domain, not locally.

### 3.7 Release build (any environment)
Always build with the script — it validates the configuration file (https for staging/production, no empty address)
before building:
```bash
cd waiter-app
tool/release.sh android production          # signed APK + AAB (needs android/key.properties, see 3.9)
tool/release.sh android staging             # same for the staging server
tool/release.sh android development         # test APK for your own backend (debug key is fine)
tool/release.sh ios production              # Mac: prepares Xcode with these values and opens it
DEVELOPMENT_TEAM=<Team ID> tool/release.sh ios-ipa production   # Mac: builds an .ipa without Xcode's UI
```
The version comes from `pubspec.yaml` (`version: 1.4.2+2`). Outputs: `build/dist/giftcard-waiter-<environment>-<version>.apk`
and `.aab`, `build/ios/ipa/*.ipa`, symbols in `build/symbols/`. File a **production** release into `releases/` with
`scripts/collect-release.sh` (section 8).

### 3.8 TestFlight build (Mac)
1. `cd waiter-app && tool/release.sh ios production` (writes the configuration, runs `pod install`, opens Xcode).
2. Xcode: *Runner* → *Signing & Capabilities* → your Team; destination **Any iOS Device (arm64)**.
3. **Product → Archive** → *Distribute App* → **App Store Connect** → *Upload*.
4. App Store Connect → your app → **TestFlight**: wait for processing (10–30 min), confirm *No* for non-exempt
   encryption if asked, add testers.
First time only (app record, Team ID on the server, App Store link): [docs/MOBILE_RELEASE.md → iOS](docs/MOBILE_RELEASE.md#ios-testflight).
A TestFlight build for the staging server: `tool/release.sh ios staging` (same steps).

### 3.9 Play Store build
1. One-time: create `waiter-app/android/key.properties` (never commit it) — values in `signing/ANDROID_SIGNING.md`:
```
storeFile=../../signing/giftcard-waiter-upload.jks
storePassword=<password from signing/ANDROID_SIGNING.md>
keyAlias=upload
keyPassword=<same password>
```
2. `cd waiter-app && tool/release.sh android production` → `build/dist/giftcard-waiter-production-<version>.aab`.
3. `scripts/collect-release.sh` (files it under `releases/<version>/android/`).
4. Upload: section 8, step 7.
First Play Console setup (app, store listing, data safety, review access): [docs/MOBILE_RELEASE.md → Android](docs/MOBILE_RELEASE.md#first-google-play-release-needs-your-play-console-account).
A production build only works for waiters once `https://app.giftcardpro.at` exists (section 11).

---

## 4. Customer app

**There is no customer app.** Guests tap or scan their card and get the balance page in the browser
(`https://<domain>/c/<token>`), which is part of the dashboard (`dashboard/src/app/c/[token]`). It runs whenever
the dashboard runs (section 2) — locally e.g. `http://localhost:3000/c/<token>` (the link is on every card page).

---

## 5. Start the complete project locally

Everything on your Mac, with demo data. Five steps, one terminal each (4 and 5 only if you need them).

**1 · Database** — choose one (details in 1.3):
```bash
# A: SQLite (nothing to start). One-time: DB_CONNECTION=sqlite etc. in backend/.env, then
touch backend/database/database.sqlite
# B: MySQL + Redis + Mailpit in Docker
docker compose -f docker-compose.dev.yml up -d
```
First time (and whenever you want fresh demo data): `cd backend && php artisan migrate:fresh --seed`.

**2 · Backend** (terminal 1):
```bash
cd backend && php artisan serve                        # http://localhost:8000   (emulator, simulator, USB phone)
cd backend && php artisan serve --host=0.0.0.0         # instead, if a phone on your Wi-Fi must reach it (3.4 B)
```
With database B also `cd backend && php artisan queue:work` (terminal 1b) so e-mails are sent (Mailpit: http://localhost:8025).

**3 · Dashboard** (terminal 2):
```bash
cd dashboard && npm run dev                            # http://localhost:3000 → owner@bellavista.test / Password123!
```

**4 · Waiter app** (terminal 3) — see 3.3–3.6 for the device you use:
```bash
cd waiter-app && flutter run --dart-define-from-file=config/development.json     # Android emulator
```
Sign in as `waiter@bellavista.test` / `Password123!`.

**5 · Customer page** — there is no customer app. Open a card in the dashboard and use its guest link
(`http://localhost:3000/c/<token>`) in any browser; with 3.4 B set up, `http://192.168.1.20:3000/c/<token>` works
on a phone too (start the dashboard with `npm run dev -- -H 0.0.0.0`).

Check: http://localhost:8000/api/v1/app/config?platform=android&version=1.4.2 returns JSON, http://localhost:3000 shows
the login, the waiter app reaches its sign-in screen.

---

## 6. NFC programming

### 6.1 What it is
Blank NFC tags (NTAG213/215/216) are programmed with the card link from the **dashboard**, in **Chrome on an Android
phone** (Web NFC): *Gift cards → Program NFC tags* for many cards (programming station), or on one card
*⋯ → Write NFC tag*. Every tag is written, read back, verified and only then saved (with the chip serial number).
There is nothing separate to install — code map in [nfc/README.md](nfc/README.md), full guide in [docs/NFC.md](docs/NFC.md).

### 6.2 How to start it (local development)
1. Backend + dashboard running on the computer (sections 1.6, 2.2) with demo data.
2. Android phone connected by USB with USB debugging (section 3.4), then forward the dashboard port —
   Web NFC only works on `https` or `localhost`, so this is what makes it work locally:
```bash
adb reverse tcp:3000 tcp:3000
```
3. On the phone, in **Chrome**: open `http://localhost:3000`, sign in as `manager@bellavista.test`,
   *Gift cards → Program NFC tags* → *Start*, allow NFC when Chrome asks.
4. Hold a blank tag flat against the back of the phone until the green tick; the next card comes up by itself.
   Label each tag with the card number shown on screen.

On a server (staging/production) just open `https://<domain>` in Chrome on the phone — no cable needed.

### 6.3 How to test it
| Test | Command / action | Needs |
|---|---|---|
| Unit tests (workflow, chip detection, errors) | `cd dashboard && npm test` | nothing |
| Server rules | `cd backend && php artisan test --filter='NfcProgrammingTest\|CardScanTest'` | nothing |
| Browser test with a simulated NFC field (7 failure classes, lock, clone) | `cd e2e && npm run test:nfc` (section 9) | backend + dashboard running |
| **Real tags on real phones** — required before a release that changes NFC | the 14 cases of [docs/NFC-RELEASE-TEST.md](docs/NFC-RELEASE-TEST.md) (~45 min per phone) | Pixel + Samsung, blank tags |

### 6.4 Browser requirements
- **Chrome for Android 89 or newer** (current Chrome recommended). Samsung Internet, Firefox, Opera: not supported.
- A **secure page**: `https://…`, or `http://localhost` (via `adb reverse`). A plain `http://192.168.…` address does
  not work.
- NFC permission for the site (Chrome asks on first use; if denied: Chrome → site settings → NFC).
- Page in the foreground, screen on (the station keeps the screen on by itself).

### 6.5 Android requirements
- A phone with NFC, **NFC switched on** (*Settings → Connected devices → NFC*).
- Android 13+ recommended (the release test uses a Pixel and a Samsung Galaxy).
- Hold the tag flat on the upper back of the phone (the antenna position varies per model) for about a second.

### 6.6 Known limitations
- **iPhone and desktop browsers cannot write tags** (no Web NFC). The dialog then shows the link for an external
  writer app and *Mark as written*; such cards are **not verified and store no chip serial**, so clone detection
  does not protect them.
- **NTAG 424 DNA** cannot be programmed in the dashboard (refused as *Wrong tag type*); provision them with NXP
  TagWriter or a desktop tool as described in docs/NFC.md.
- Only NTAG213/215/216 are detected; other chip types are refused.
- Clone detection relies on factory UIDs; "magic" UID-changeable clones exist (use NTAG 424 DNA for high values).
- The automated tests use a **simulated** NFC field; the real-tag release test has **not been done yet**.
- The native waiter app **reads** tags only; it never writes them.

---

## 7. Database

Migrations live in `backend/database/migrations/` (one file per change, never edit an applied one). Run all
commands in `backend/`. Current schema version: see [CURRENT_VERSION.md](CURRENT_VERSION.md).

### 7.1 Create a new migration
```bash
cd backend
php artisan make:migration add_example_column_to_gift_cards_table
# edit the new file in database/migrations/: up() makes the change, down() undoes it
php artisan migrate
php artisan migrate:status       # shows which migrations ran
```
Rules for this project (tables use UUIDs, `restaurant_id` for tenant data, nothing is ever deleted, changes must be
compatible with the previous release during deploys): [docs/DEVELOPMENT.md → Adding a feature](docs/DEVELOPMENT.md#adding-a-feature--checklist),
schema: [docs/DATABASE.md](docs/DATABASE.md). Update `docs/DATABASE.md` in the same change.

### 7.2 Roll back
```bash
php artisan migrate:rollback --step=1     # undo the last migration
php artisan migrate:rollback              # undo the last batch
php artisan migrate:fresh --seed          # LOCAL ONLY: drop everything, migrate, demo data
```
In production, do not roll back: fix forward with a new migration (rollbacks can drop data), and restore a backup
only for real data loss.

### 7.3 Restore a backup
Production backups are daily dumps `giftcard_pro_<UTC timestamp>.sql.gz` in the `mysql-backups` volume, written by
the `backup` service (plus your off-site copy) — [docs/DEPLOYMENT.md → Backups](docs/DEPLOYMENT.md#backups).
All commands below run in Coolify → *Terminal*.

**Test the backup first (safe, every month):** container **backup**:
```bash
ls -lh /backups
mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE giftcard_pro_restore"
gunzip -c /backups/giftcard_pro_<date>.sql.gz | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro_restore
mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE giftcard_pro_restore"   # after checking
```

**Real restore (replaces live data):**
1. Container **api**: `php artisan down`
2. Container **backup**: take a dump of the current state first, then restore:
   ```bash
   mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --no-tablespaces \
     "$MYSQL_DATABASE" | gzip > /backups/before_restore_$(date -u +%Y%m%dT%H%M%SZ).sql.gz
   gunzip -c /backups/giftcard_pro_<date>.sql.gz | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
   ```
3. Coolify → *Redeploy* (runs migrations newer than the dump and brings the app back up).

**Local MySQL (setup B):** `gunzip -c dump.sql.gz | docker compose -f docker-compose.dev.yml exec -T mysql mysql -uroot -proot giftcard_pro`.
**Local SQLite:** copy the file back over `backend/database/database.sqlite`.

---

## 8. Release

A release has one version number for everything (platform = backend + dashboard + waiter app). Example: 1.4.2.

1. **Version.** `waiter-app/pubspec.yaml` → `version: 1.4.2+2` (the number after `+` goes up with *every* store
   upload). Add `## 1.4.2: …` at the top of `CHANGELOG.md`.
2. **Tests** — all must pass:
   ```bash
   (cd backend && php artisan test && vendor/bin/pint --test && vendor/bin/phpstan analyse)
   (cd dashboard && npm run lint && npm run typecheck && npm test && npm run build)
   (cd waiter-app && flutter analyze && flutter test)
   (cd e2e && npm test && npm run test:waiter-api && npm run test:nfc && npm run test:admin)   # backend + dashboard running
   ```
   If NFC code changed: the real-tag test (section 6.3).
3. **Server (backend + dashboard).** Push to `main` (optionally tag it: `git tag v1.4.2 && git push --tags`) →
   Coolify builds everything from source and deploys ([docs/DEPLOYMENT.md](docs/DEPLOYMENT.md#updates)).
   The new Laravel containers run the migrations before they start serving. Check `https://app.giftcardpro.at/up`.
4. **APK + AAB:** `cd waiter-app && tool/release.sh android production`
5. **IPA / TestFlight (Mac):** `cd waiter-app && tool/release.sh ios production` → Xcode *Archive* → *Upload* (section 3.8),
   or `DEVELOPMENT_TEAM=<Team ID> tool/release.sh ios-ipa production` → `build/ios/ipa/*.ipa` → upload with Apple's
   **Transporter** app.
6. **File the release:** `scripts/collect-release.sh` → `releases/1.4.2/` (APK, AAB, IPA if built, symbols, mapping,
   source zip, checksums); the previous release moves to `releases/previous/`, `releases/latest` → `1.4.2`.
7. **Play Store upload:** [Play Console](https://play.google.com/console) → GiftCard Waiter → *Test and release →
   Testing → Internal testing* → *Create new release* → upload `releases/latest/android/app-release.aab` → release
   notes (DE/EN) → *Next* → *Save and publish*. Upload `android/r8-mapping-*.txt.gz` (unzipped) under
   *App bundle explorer → Downloads*. After testing: *Promote release* → Closed testing → Production.
8. **TestFlight → App Store:** after testing in TestFlight, App Store Connect → *Distribution* → new version 1.4.2 →
   choose the build → *Add for Review*.
9. **Record it:** update [CURRENT_VERSION.md](CURRENT_VERSION.md) (versions, locations, release date, production
   status), then `scripts/verify-structure.sh`.
10. **Old app versions:** after both stores have the new version, raise *Minimum waiter app version* in the platform
    admin → *System settings*, if old versions must stop working.

Detailed store steps and the release checklist: [docs/MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md).

---

## 9. Acceptance tests (e2e)

Real-browser tests against a running stack (backend on :8000 — invitation links are read from Mailpit, or from the log with `LOG_LEVEL=debug`,
dashboard on :3000, demo data).
```bash
cd e2e
npm install
npx playwright install chromium
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test   # pilot journey (~2 min)
API_URL=http://localhost:8000 npm run test:waiter-api                        # API of the native app
npm run test:nfc                                                             # NFC programming, simulated tags
npm run test:admin                                                           # platform administration (restaurants, invitations)
```
Details: [e2e/README.md](e2e/README.md).

---

## 10. When something does not work

| Problem | Fix |
|---|---|
| Dashboard login loops / 419 | Backend not running, or `SANCTUM_STATEFUL_DOMAINS` in `backend/.env` does not contain `localhost:3000`. |
| `could not find driver` | PHP without `pdo_sqlite` / `pdo_mysql`: use Homebrew's `php@8.4`. |
| `Class "Redis" not found` | Set `REDIS_CLIENT=predis` in `backend/.env`. |
| Waiter app shows *Server not found* | The address in `config/<environment>.json` (or the one set with the DEV ribbon) does not exist in DNS — e.g. `app.giftcardpro.at` before the domain is registered. Use the development environment (section 3.3/3.4). |
| Waiter app shows *Server not running* | Nothing answers at that address: start `php artisan serve` (with `--host=0.0.0.0` for Wi-Fi phones), check the port and the macOS firewall. |
| Waiter app shows *Server not responding* | Phone and computer not in the same network, VPN, or the IP changed (`ipconfig getifaddr en0`; long-press the DEV ribbon to enter the new one). |
| Waiter app shows *Wrong server address* | Something answers, but not the API: the address must end in `/api/v1` and point at the backend (port 8000), not the dashboard (3000). |
| Waiter app: *No connection* on the emulator | Use `10.0.2.2`, not `localhost`; backend running. |
| Waiter app: *No connection* on a USB phone | Run `adb reverse tcp:8000 tcp:8000` again after reconnecting the cable. |
| Waiter app: card not recognised | `CARD_DOMAINS` must be the host of the card links (`localhost` locally). |
| *NFC is not available* in the dashboard | Not Chrome on Android, not `https`/`localhost`, NFC off, or permission denied (section 6.4). |
| `tool/release.sh android`: key.properties missing | Section 3.9 step 1. |
| iOS: signing / capability errors | Select your Team in Xcode; NFC and Associated Domains need a paid account. |
| `tool/release.sh`: API_BASE_URL is empty | `config/staging.json` has no server yet — fill it in or build another environment. |
| Check the folder layout | `scripts/verify-structure.sh` |

---

## 11. Production (giftcardpro.at)

Nothing in production exists yet: the domain `giftcardpro.at` is not registered (DNS answers NXDOMAIN), so
production builds of the app show *Server not found*. The complete first deployment on Coolify — domain, DNS, server, HTTPS,
e-mail, backups, app links — is in [docs/DEPLOYMENT.md → First deployment](docs/DEPLOYMENT.md#first-deployment--step-by-step).
