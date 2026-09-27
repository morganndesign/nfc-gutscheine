# Quick commands

Cheat sheet. Run from `GiftCardPro/` unless a `cd` is shown. Explanations: [RUNNING_THE_PROJECT.md](RUNNING_THE_PROJECT.md).
Demo logins: `admin@` / `owner@` / `manager@` / `waiter@bellavista.test` … password `Password123!`

```bash
# ── Local services (optional: MySQL, Redis, Mailpit) ─────────────────────────
docker compose -f docker-compose.dev.yml up -d          # start   (Mailpit: http://localhost:8025)
docker compose -f docker-compose.dev.yml down           # stop

# ── Backend (Laravel API) — http://localhost:8000 ───────────────────────────
cd backend
composer install                                        # dependencies
cp .env.example .env && php artisan key:generate        # first time only, then edit .env
php artisan migrate                                     # apply migrations
php artisan db:seed                                     # reference + demo data
php artisan migrate:fresh --seed                        # LOCAL reset: wipe, migrate, demo data
php artisan serve                                       # dev server
php artisan serve --host=0.0.0.0 --port=8000            # reachable from phones on the Wi-Fi
php artisan queue:work                                  # queue worker (e-mails) with QUEUE_CONNECTION=redis
php artisan schedule:work                               # nightly jobs
php artisan platform:create-admin you@example.com --name="Your Name"
php artisan route:list --path=api                       # all API routes

# ── Dashboard (Next.js) — http://localhost:3000 ─────────────────────────────
cd dashboard
cp .env.example .env.local                              # first time only
npm install                                             # dependencies (npm ci = exact lockfile)
npm run dev                                             # dev server
npm run build && npm start                              # production build, run locally

# ── Flutter (waiter app) ─────────────────────────────────────────────────────
cd waiter-app
flutter pub get                                         # packages
flutter doctor                                          # toolchain check
flutter devices                                         # connected phones / emulators
flutter emulators --launch <id>                         # start an Android emulator
# Environments: config/development.json · staging.json · production.json (your own: <env>.local.json)
flutter run --dart-define-from-file=config/development.json          # Android emulator → your computer (10.0.2.2:8000)
adb reverse tcp:8000 tcp:8000                                        # USB phone: its localhost:8000 = your computer
flutter run --dart-define-from-file=config/development.local.json    # phone / simulator with your own address
ipconfig getifaddr en0                                               # your Mac's IP for development.local.json
# In a DEV / STAGING build: long-press the corner ribbon to change the server without rebuilding
dart run tool/generate_tokens.dart                      # after editing tokens/waiter.tokens.json
dart run tool/import_strings.dart                       # after editing the UI copy (docs/design/…/12)

# ── NFC programming (dashboard on an Android phone) ──────────────────────────
adb reverse tcp:3000 tcp:3000                           # then Chrome on the phone: http://localhost:3000
                                                        # → Gift cards → Program NFC tags

# ── Tests ────────────────────────────────────────────────────────────────────
(cd backend && php artisan test)                        # PHPUnit (SQLite in memory)
(cd backend && php artisan test --filter=NfcProgrammingTest)
(cd backend && vendor/bin/pint --test && vendor/bin/phpstan analyse)   # style + static analysis
(cd dashboard && npm run lint && npm run typecheck && npm test)
(cd waiter-app && flutter analyze && flutter test)
(cd e2e && npm install && npx playwright install chromium)            # first time
(cd e2e && npm test)                                    # pilot journey   (backend + dashboard running)
(cd e2e && npm run test:waiter-api)                     # waiter app API
(cd e2e && npm run test:nfc)                            # NFC programming, simulated tags

# ── Database ─────────────────────────────────────────────────────────────────
(cd backend && php artisan make:migration add_x_to_y_table)
(cd backend && php artisan migrate:status)
(cd backend && php artisan migrate:rollback --step=1)
# restore (server): see RUNNING_THE_PROJECT.md §7.3
gunzip -c backups/giftcard_pro_<date>.sql.gz | docker compose --env-file .env.production exec -T mysql \
  sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'

# ── Build Android ────────────────────────────────────────────────────────────
(cd waiter-app && tool/release.sh android production)   # signed APK + AAB → waiter-app/build/dist/
(cd waiter-app && tool/release.sh android development)  # test APK for your own backend ("GiftCard Waiter Dev")
(cd waiter-app && tool/release.sh android staging)      # staging server (config/staging.json must be filled in)
adb install -r waiter-app/build/dist/giftcard-waiter-development-<version>.apk   # install on a USB phone
adb install -r releases/latest/android/app-release.apk  # install the current release

# ── Build iOS (Mac) ──────────────────────────────────────────────────────────
(cd waiter-app && tool/release.sh ios production)       # opens Xcode → Product → Archive → Upload (TestFlight)
(cd waiter-app && DEVELOPMENT_TEAM=<TeamID> tool/release.sh ios-ipa production)   # .ipa → Transporter app

# ── Production release ───────────────────────────────────────────────────────
# 1. version in waiter-app/pubspec.yaml (e.g. 1.4.2+2) + CHANGELOG.md section
# 2. all tests above
git tag v1.4.2 && git push --tags                       # 3. server deploy via GitHub Actions
(cd waiter-app && tool/release.sh android production)   # 4. APK + AAB
(cd waiter-app && tool/release.sh ios production)       # 5. TestFlight (Mac)
scripts/collect-release.sh                              # 6. file into releases/<version>, latest → it
# 7. Play Console → Internal testing → upload releases/latest/android/app-release.aab
# 8. update CURRENT_VERSION.md
scripts/verify-structure.sh                             # 9. check folders, versions, checksums, links

# ── Server (production) ──────────────────────────────────────────────────────
docker compose --env-file .env.production up -d
docker compose --env-file .env.production ps
docker compose --env-file .env.production logs -f api
docker compose --env-file .env.production exec api php artisan migrate:status
docker compose --env-file .env.production --profile backup run --rm backup   # backup now
curl -fsS https://app.giftcardpro.at/up                 # health check
```
