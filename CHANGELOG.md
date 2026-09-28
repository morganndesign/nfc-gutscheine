# Changelog

## 1.4.2 (in development): environments for the waiter app, no more endless launch screen

**Why the 1.4.1 app stayed on the splash screen.** Reproduced with the 1.4.1 release APK on an Android 9 emulator:
without a screen lock it reached *Sign in*; with a PIN set (like every real phone) it never drew a frame. The
symbolised Dart stack trace (release symbols) showed `FlutterSecureStorage.deleteAll` ← `bootstrap` (first start) ←
`main` failing with `PlatformException: At least one fingerprint must be enrolled to create keys requiring user
authentication for every use`. `PlatformSecretStore` used `KeyCipherAlgorithm.AES_GCM_NoPadding`, which
flutter_secure_storage 10+ treats as its **biometric mode**; the exception happened in `main()` before `runApp`,
so the native launch screen stayed forever. The missing domain was not the cause: the unreachable `/app/config`
was already non-blocking (2 s) and would have led to *Sign in*.

| Change | Why |
|---|---|
| Secure storage uses the plugin's standard mode (AES-GCM data, RSA-wrapped key in the Android Keystore, no user authentication). | The cause of the hang; the token must never be gated by biometrics (09 §7.6). |
| `main` catches every start-up failure (and a start that takes > 20 s) and shows the **startup problem screen** with the reason and *Try again*. The launch decision has its own 20 s watchdog and catches exceptions. | No failure can leave the app on the launch screen again. |
| Signed out and `/app/config` unreachable → the startup problem screen instead of a sign-in form that cannot work, with the reason: no internet, server not found (DNS), server not running (refused), no answer / no route, certificate rejected, server error (5xx), wrong address (404, HTML, redirect, other JSON); plus invalid build configuration and unusable secure storage. Shows the server address, the technical detail and a support code; retries on *Try again*, when the network returns and on foreground. Signed-in waiters are not blocked. 39 new strings in 12 §5.2 (DE/EN/BHS). | Requirement: a proper error screen with the reason. |
| **Environments** development / staging / production from `waiter-app/config/<environment>.json` (`--dart-define-from-file`), `APP_ENV` define; `tool/release.env` removed. Staging/production require https; a missing `APP_ENV` applies the production rules; invalid values are reported, not ignored. | The API address is no longer tied to one build command; switching environment needs no code change. |
| Development and staging builds: own Android application id (`.dev`, `.staging`) and launcher name, a DEV / STAGING corner ribbon; long-press it (or *Change server* on the problem screen) to enter another server address — stored, applied at once, signs out. Production builds cannot change their server. Development builds allow plain http (own network security config). | Test on phones against a backend on the local network without rebuilding; dev and store app side by side. |
| `tool/release.sh <android \| ios \| ios-ipa> <environment>` validates the config file and writes `build/dist/giftcard-waiter-<environment>-<version>.apk/.aab` plus the symbols and mapping of that build; `scripts/collect-release.sh` files only production builds. CI builds with `config/production.json`. | Clear, safe build outputs per environment. |
| Transport failures are classified (`TransportIssue`: timeout, host lookup, refused, unreachable, TLS). Card links accept http only in the development environment. | Reasons on the problem screen; no http card links in store builds. |
| Deployment docs: go-live checklist for `giftcardpro.at`; `APP_KEY` via `openssl`, `--entrypoint php` for one-off artisan commands (the image's start script would try to migrate). | The previous commands could not work before the database was running. |
| **Environment safety audit:** the iOS app-link host is no longer fixed in the Xcode project (`tool/release.sh` writes `ios/Flutter/Environment.xcconfig` from the environment's config); the dashboard has no default backend URL (`BACKEND_INTERNAL_URL` required in development, unset in production); the API refuses to start in staging/production with missing, http, placeholder or local `APP_URL` / `FRONTEND_URL` / `CARD_BASE_URL` (`EnvironmentGuard`); a stored sign-in is dropped when the app talks to another server; staging templates `backend/.env.staging.example` and `.env.staging.example`; one environment table in `docs/ENVIRONMENT.md`; `scripts/verify-structure.sh` checks for legacy configuration. | Production and development can no longer be mixed up by a default value or a leftover setting. |
| Tests: 626 Flutter tests, 167 PHPUnit tests (EnvironmentGuard 10), (23 new: environments, failure classification, problem screen for every reason, watchdog, server change, badge). Verified on an Android 9 emulator with a PIN: the production APK shows the problem screen instead of hanging; the development APK reached the local backend and *Sign in* after changing the server in the app. | |

## Test e-mail recipient and German invitation e-mail, 28 September 2026 (part of 1.4.2)

In production (SMTP working, invitations arriving in Gmail) **Send test e-mail** failed with
`550 Unrouteable address`. The action (`PlatformController::sendTestMail`, `POST /admin/mail/test`) did send to the
signed-in platform admin (`$request->user()`, Sanctum → session guard `web` in the dashboard). A 550 after the
server accepted connection, login and sender means that recipient address — the admin account's own — or its
domain cannot receive mail.

| Change | Why |
|---|---|
| Test e-mail: recipient = optional `to` or the signed-in admin; logged before sending ("Platform test e-mail requested": recipient, source, user id, guard, mailer); a missing or invalid address — or, with `MAIL_VERIFY_DOMAINS` (default on), a domain without mail server — is a `422` validation error on `to` and nothing is sent; a 550–553 answer is reported as `MAIL_RECIPIENT_REJECTED` naming the address; response contains `recipient`, `mailer`, `guard`. | Make the recipient visible and never deliver to a missing or impossible address. |
| System settings → E-mail delivery: shows mailer and SMTP server (`host:port`, no credentials); **Send test e-mail** with a recipient field pre-filled with the admin's address. The red banner still appears only while `MAIL_MAILER=log`. | Test with any mailbox; confirm the production settings at a glance. |
| Invitation e-mail in German (default) with natural wording and „…“ typography; English kept as a second language. All text in `lang/de/invitation.php`, `lang/en/invitation.php`; the button fallback line and footer of Laravel's (unchanged, responsive) template in `lang/de.json`, `lang/en.json`. Language = the restaurant's (`de-*` → de, `en-*` → en) or `MAIL_LOCALE` (default `de`, new compose/env variable). Greeting uses the first name. | DACH market; further languages only need translation files. |
| `platform.support_email` placeholder `support@giftcardpro.app` → `support@giftcardpro.at` (seeder; migration changes it only if still the placeholder). | Address shown in owner invitations. |
| Tests: `PlatformTestMailTest` (9), `InvitationEmailLocalizationTest` (5), invitation tests updated — 207 PHPUnit tests. Rendered HTML checked on desktop and mobile width; platform-admin and pilot journeys pass. | |

## Platform administration completed, 28 September 2026 (part of 1.4.2)

**Why invitations "were not sent".** The invitation code path existed and works: creating a restaurant sends one
e-mail to the owner (verified with the real mail stack). What was missing: no record of the attempt, a mail
error was not caught (the request failed after the restaurant was saved), no way to send it again from the
platform admin, and nothing showed that `MAIL_MAILER=log` — the default Coolify pre-fills from the compose file —
writes e-mails to the log only. Each of these is fixed below.

| Change | Why |
|---|---|
| `InvitationService`: one place that issues the token (password broker `invitations`: random, stored hashed, 72 h, a new one replaces the old), sends `StaffInvitation`, and records every attempt in `notification_logs` (`staff_invitation`: `sent`, `failed` with the mail server's error, or `logged` when `MAIL_MAILER=log`). Mail errors no longer break the request. Invitation state per account: `accepted`, `pending` (with expiry), `expired`, `not_sent`. | Invitations must be traceable and failures visible. |
| Owner invitation text: "…invited you to set up <restaurant>… owner account"; expired links point to `platform.support_email` (staff invitations still say "ask your restaurant owner"). Accepting logs `user.invitation_accepted`. | Owners have no owner to ask. |
| Restaurant lifecycle: **Edit** (profile + plan; currency only before the first gift card), **Disable/Enable** (existing suspend), **Archive/Restore** (soft delete: hidden, users and devices locked out, data kept), **Delete** permanently with the short name typed as confirmation — refused with `409 RESTAURANT_NOT_DELETABLE` and the counts when gift cards, transactions or customers exist; otherwise users, tokens, sessions, pending invitations, devices, settings and own templates are removed, audit and notification logs kept. | Requested CRUD; financial records must never disappear. |
| **Invite again** for the owner (`POST /admin/restaurants/{id}/invitation`, can correct a mistyped name/e-mail; the old link stops working) and for any pending account (`…/users/{user}/invitation`); refused for accepted, disabled or archived. | "Invite again" action; typo recovery without support tickets. |
| Mail diagnostics: `GET /admin/mail`, `POST /admin/mail/test`; red banner on the platform pages while e-mails are not delivered; **E-mail delivery** card with **Send test e-mail to me** in System settings. | The production symptom ("invitations not sent") is now visible in the product. |
| Admin UI: list with **Restaurant · Owner · Email · Status · Created · Actions** (Edit · Invite again · Disable/Enable · Archive/Restore · Delete), status filter (All/Active/Disabled/Archived), search by owner name/e-mail, invitation badge with details; create dialog reports undelivered invitations; detail page with all actions, archived/disabled notices, business-data counts, per-user invitation state and **Invite again**, link to the restaurant's audit log; audit page filters (action prefix, restaurant); labels for the new audit events. | Requested admin UX and audit of dead ends. |
| Accessibility: destructive badges (Disabled, Revoked, Locked, Off) use darker text — the previous red on red tint failed WCAG AA contrast. Invitation password field requires 12 characters as its hint says (was 10). | Found by the new axe scan. |
| Tests: `RestaurantManagementTest` (9), `OwnerInvitationTest` (10, real mail transport), `PlatformAdminAuthorizationTest` (every admin endpoint × owner/manager/waiter/guest), `PlatformAdminTest` updated — 193 PHPUnit tests (25 new). New browser journey `e2e/platform-admin.mjs` (`npm run test:admin`); pilot, waiter-API and NFC journeys pass unchanged. | |

## Coolify: fail-fast for missing generated values, 28 September 2026 (part of 1.4.2)

A stack with empty `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD` and `DB_PASSWORD` was found on the server (project
`nfc-gutscheine`, containers `nfc-gutscheine-*-1`, compose file `/tmp/nfc-gutscheine/…`). The variable names are
correct for Coolify 4.x (`SERVICE_PASSWORD_<NAME>` with one name part → type `PASSWORD`, generated by Coolify's
compose parser; `SERVICE_URL_<SERVICE>_<PORT>` → domain); that project name and container naming are Docker
Compose's own, not Coolify's (`<service>-<application uuid>`, labels `coolify.managed=true`), and the empty values
are reproduced exactly by running the file with plain `docker compose` in a folder of that name.

| Change | Why |
|---|---|
| `docker-compose.coolify.yml`: `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` and `SERVICE_URL_GATEWAY` are referenced as `${VAR:?message}`. | If one is missing, Compose stops before creating any container with a message naming the variable, instead of MySQL/Laravel restarting with empty passwords. Coolify's parser still generates them (magic variables are collected in its first pass over all services, before default/required syntax is processed). |
| CI and `scripts/verify-structure.sh`: the file must refuse to start without the generated values and be valid with them. `docs/DEPLOYMENT.md`: troubleshooting for the message and for stacks not started by Coolify. | |

## Coolify: no ARG injection, bounded build steps, 27 September 2026 (part of 1.4.2)

Coolify added 102 `ARG` lines (one per environment variable) to every stage of the API and web Dockerfiles, then
the log stopped at *Pulling & building required images* (Coolify runs the build with hidden output).

| Change | Why |
|---|---|
| `docker-compose.coolify.yml`: the `dockerfile:` of every build is written as `${LARAVEL_DOCKERFILE:-backend/Dockerfile}`, `${WEB_DOCKERFILE:-Dockerfile}`, `${GATEWAY_DOCKERFILE:-Dockerfile}` (same files). | Coolify skips its Dockerfile rewrite when the path contains a variable (`ApplicationDeploymentJob::resolveComposeDockerfilePath`). The injected ARGs are recorded in the image history of every `RUN` step — verified: DB password and APP_KEY readable with `docker history` — and they invalidate the build cache on every change of any variable. The Dockerfiles need no build arguments. |
| `backend/Dockerfile`: `yes '' \| timeout 600 pecl install redis` (answers pecl's questions with the defaults, 10-minute limit); `timeout 900 composer install`. | `pecl` and `composer` download over the network without an overall deadline; a stalled mirror could block the build forever. |
| `dashboard/Dockerfile`: `timeout 900 npm ci --fetch-timeout=60000 --fetch-retries=3`; `timeout 1800 npm run build`. | `npm ci` can stall without ever finishing when the registry connection breaks (seen here as "Exit handler never called"); a starved Next.js build now fails instead of running without end. |
| `scripts/verify-structure.sh` checks that every build uses a variable Dockerfile path and that no Dockerfile declares `ARG`. `docs/DEPLOYMENT.md`: troubleshooting for a silent build and for the ARG message. | |
| Tested: Coolify-style `docker compose build` with ~100 `--build-arg` values (including passwords): web and gateway built in 109 s, no secret in any image history; Dockerfile lint clean; the injected-ARG leak reproduced on a test image; the timeout wrapper returns 143 on a stalled step. The API image could not be rebuilt here (pecl.php.net is not reachable from the test machine). | |

## Coolify: every container starts in one step, 27 September 2026 (part of 1.4.2)

On a real Coolify server `mysql`, `redis` and `web` started, but `docker compose up` stopped on a `depends_on`
health condition, and `gateway`, `migrate`, `api`, `worker` and `scheduler` stayed in *Created*.

| Change | Why |
|---|---|
| `docker-compose.coolify.yml` simplified: no `depends_on`, no one-shot `migrate` service, no `restart: "no"`, no profiles, no YAML anchors; eight long-running services with `restart: unless-stopped`; the Laravel environment written out per service. | `docker compose up -d` starts every container immediately and cannot abort on a dependency condition. |
| `infra/docker/php/entrypoint.sh`: each Laravel container waits for MySQL and Redis (up to 15 min), runs `migrate --force --isolated` (one container at a time via a Redis lock, the others wait until nothing is pending), `api` seeds reference data, then starts. APP_KEY generation is atomic (`ln`) because several containers start at the same time. Role `migrate` removed. | The start order now lives inside the containers instead of in Compose. |
| MySQL health check: `mysqladmin ping -h 127.0.0.1` without credentials, `start_period` 180 s, `timeout` 10 s, `retries` 12. MySQL flags are fixed (`innodb-buffer-pool-size=512M`, no `sh -c` wrapper); `MYSQL_INNODB_BUFFER_POOL_SIZE` removed. | Fresh volumes initialise slowly on small servers; the check cannot hang on a password prompt. |
| `backup` has no health check and no dependency; long start periods for `api`, `worker`, `scheduler` (300 s). | No container is marked unhealthy while it waits for the database or migrations. |
| `scripts/verify-structure.sh` fails on `depends_on`, `profiles`, `restart: no`, health conditions and anchors. Docs updated (`DEPLOYMENT.md`, `DOCKER.md`, `ENVIRONMENT.md`, `RUNNING_THE_PROJECT.md`, `.env.production.example`). | |
| Tested on fresh volumes with Coolify's command (`env_file: .env` injected, `--env-file`, `up -d`): `up` returns in 2 s with all eight containers running; all healthy after ~35 s; exactly one container ran the migrations; one APP_KEY shared by all; `/up`, `/login`, `/api/v1/app/config` 200; redeploy with kept volumes healthy, no migrations re-run. | |

## Coolify: configuration from the environment only, 27 September 2026 (part of 1.4.2)

`docker compose config` in Coolify's helper container reported `env file /artifacts/<id>/.env not found`. The
repository had no `env_file`; Coolify adds `env_file: .env` to every service of its rewritten compose file and
writes that file only after the build (checked in Coolify's `ApplicationDeploymentJob`). The deployment was audited
and hardened so that nothing depends on any `.env` file.

| Change | Why |
|---|---|
| `docker-compose.coolify.yml`: `exclude_from_hc` removed from `migrate` (Coolify already excludes `restart: "no"` services from health). | It was the only non-standard key: plain `docker compose -f docker-compose.coolify.yml config` rejected the file. Now it passes with no `.env` file and no extra flags. |
| MySQL flags start through `sh -c "exec docker-entrypoint.sh mysqld …"` and read `MYSQL_INNODB_BUFFER_POOL_SIZE` from `environment:`. | The only `${…}` outside an `environment:` block; everything is now configured through `environment:` only. |
| Header of the compose file states the rule: no `env_file`, every variable has a default except Coolify's generated `SERVICE_*` values. | |
| `.dockerignore`: every `.env` / `.env.*` (except `*.env.example`) is excluded from all images. | A local development `.env` can never reach a production image. |
| CI validates the unmodified compose file with no `.env` present and fails on any `env_file`. `scripts/verify-structure.sh` checks: no `env_file` / `--env-file`, only standard keys, `config` passes from an empty directory. | Keeps it that way. |
| `docs/DEPLOYMENT.md`: troubleshooting entry for the message. | |
| Tested: Coolify's flow reproduced (rewritten compose with `env_file: .env`, build with `--env-file /artifacts/build-time.env`, up with `--env-file <workdir>/.env`): all services healthy, `migrate` exited 0, MySQL runs with the configured flags, no `.env` inside any container. 168 PHPUnit tests pass. | |

## Coolify deployment, 27 September 2026 (part of 1.4.2)

The previous production deployment pulled pre-built images from GitHub Container Registry, built by a GitHub
Actions workflow and started by a shell script over SSH. It could not be deployed by Coolify. It was replaced by a
new deployment designed for Coolify: connect the repository, press *Deploy*.

| Change | Why |
|---|---|
| New `docker-compose.coolify.yml`: gateway, migrate, api, worker, scheduler, web, mysql, redis, backup. Every application image is **built from source** on the server; no registry, no GitHub Actions step, no published host ports. Health checks, `unless-stopped` restarts, named volumes (`mysql-data`, `redis-data`, `laravel-storage`, `mysql-backups`). | Coolify's Docker Compose build pack builds from the repository and routes one domain per service through its own proxy. |
| New gateway service (`infra/docker/gateway/`, Caddy): `/api`, `/sanctum`, `/up`, `/reset-password` → Laravel over FastCGI, everything else → Next.js. TLS is done by Coolify. | The product needs one origin (Sanctum cookies, card links); one domain on one container needs no proxy-specific path rules. |
| One-shot `migrate` service runs migrations (`--isolated`) and reference seeders on every deploy; api, worker and scheduler start only after it succeeded. | Migrations run automatically, exactly once, before new code serves requests. |
| `infra/docker/php/entrypoint.sh` rewritten: roles migrate/app/worker/scheduler; the public URL, cookie domain and Sanctum domain are derived from the gateway domain Coolify assigns; APP_KEY is generated on the first deploy into the storage volume unless set; clear errors for a missing domain or missing passwords. | No manual `.env` editing on the server; database/Redis passwords come from Coolify's generated `SERVICE_PASSWORD_*`. |
| Daily `mysqldump` by the `backup` service (time and retention configurable). | Replaces the host cron script. |
| `backend/Dockerfile`: build-time artisan runs with `APP_ENV=build`; storage directories created explicitly; `CONTAINER_ROLE` default. Both Dockerfiles: `# syntax=` line removed. `.dockerignore`: excludes `dashboard/` and stale `bootstrap/cache/*.php` from the backend build. | The EnvironmentGuard stopped the image build in `package:discover`; the brace expansion did not work in `sh`; the syntax line forced an extra registry lookup; a local config cache could leak into the image. |
| `.env.production.example` rewritten as the reference for Coolify's environment variables. | Only mail settings are required; everything else has production defaults. |
| **Removed:** `docker-compose.yml` (GHCR), `.github/workflows/deploy.yml`, `infra/caddy/`, `infra/scripts/deploy.sh`, `infra/scripts/backup.sh`, `.env.staging.example`, `backend/.env.production.example`, `backend/.env.staging.example`. | Parts of the old deployment; unused with Coolify and could be run by mistake. |
| CI: the docker job validates and builds the Coolify stack. `scripts/verify-structure.sh` checks for the Coolify files and that no GHCR file remains. Docs: `docs/DEPLOYMENT.md` rewritten (step by step for Coolify), `docs/DOCKER.md`, `docs/ENVIRONMENT.md`, `RUNNING_THE_PROJECT.md`, `QUICK_COMMANDS.md`, `PROJECT_STRUCTURE.md`, `docs/FOLDER_STRUCTURE.md`, `docs/SECURITY.md` updated; German/BHS technical guides carry a pointer to `docs/DEPLOYMENT.md`. | |
| Tested: complete stack built from source and started with an https test domain — all services healthy, migrate exited 0, `/up`, API, dashboard, SPA sign-in with secure cookies, queue job processed, scheduler, APP_KEY and data kept across restarts, backup dump. 168 PHPUnit tests pass. | |

## Project reorganisation, 27 September 2026 (part of 1.4.2; no code changes)

| Change | Why |
|---|---|
| One canonical project folder `GiftCardPro/` with `releases/` (current `1.4.1`, `previous/`, `latest` link), `signing/`, `assets/`, `scripts/`, `nfc/` (signpost). Duplicate copies, ZIPs and reports removed; audit reports in `docs/reports/`. | Three partial copies, five ZIPs and loose reports made it unclear which state was current. |
| `frontend/` renamed to `dashboard/`; CI working directories, Docker build contexts and docs updated. Image names (`giftcard-pro-web`) unchanged. | Name matches what the app is. |
| New `PROJECT_STRUCTURE.md`, `CURRENT_VERSION.md`, `RUNNING_THE_PROJECT.md`, `QUICK_COMMANDS.md`. | One place for how to run everything and what is current. |
| `scripts/collect-release.sh` (files a release into `releases/<version>/` with checksums and a source snapshot) and `scripts/verify-structure.sh`. `.gitignore` and `.dockerignore` exclude `releases/` and `signing/`. | Repeatable release filing; keys can never end up in Git or a Docker image. |
| `waiter-app/android/key.properties` points to `../../signing/giftcard-waiter-upload.jks`. | Works on every machine with the same folder layout. |

## 1.4.1: Store builds of GiftCard Waiter

The waiter app is versioned with the platform: **1.4.1 (build 1)**.

| Change | Why |
|---|---|
| Android release signing with a new **upload key** (kept outside the repository, `ANDROID_SIGNING.md`), `tool/release.sh android` builds the signed `app-release.apk` and `app-release.aab` with the production configuration (`tool/release.env`: `https://app.giftcardpro.at`). Dart obfuscation with kept symbols. | Store builds were debug-signed and pointed at a placeholder domain. |
| **Target SDK 36** pinned. | Google Play requirement since 31 August 2026. |
| **App data excluded from cloud backup and device transfer** (`allowBackup=false`, data extraction rules). | Required by the spec (09 §7.10) but missing: the session and settings could be restored onto another phone. |
| iOS NFC entitlement **`TAG` only**. | `NDEF` is rejected by App Store Connect (ITMS-90778). |
| iOS **privacy manifest** (`PrivacyInfo.xcprivacy`), automatic signing without a stored team (optional `Team.xcconfig`), `ExportOptions.plist`, `tool/release.sh ios` / `ios-ipa`. | Needed for App Store submission; archive-ready after selecting the team. |
| Pseudo-localisation can never be enabled in release builds. | No development switches in store builds. |
| `docs/MOBILE_RELEASE.md`: version policy, outputs, Play and TestFlight steps, release checklist. | |

## 1.4.1: NFC programming — final pass

Hardening of NFC programming v2 after a full review. The waiter app is unchanged (no file under `waiter-app/` changed).

Verification:

- **Backend:** 158 PHPUnit tests (1,044 assertions), Larastan level 8 and Pint clean.
- **Dashboard:** 32 unit tests (`node --test`); TypeScript, ESLint, Prettier and `next build` clean.
- **End to end:** `e2e/nfc-programming.mjs` extended to 8 steps: recovery from every failure class in one station session, statistics, same tag twice, redeem after a chip read, clone rejection, complete attempt log, printed timings. `pilot-journey.mjs` and `waiter-api.mjs` pass.
- **Not done:** the test with real tags on a Pixel and a Samsung phone — no devices are available to the build environment. Protocol, measurements and report template: [docs/NFC-RELEASE-TEST.md](docs/NFC-RELEASE-TEST.md).

| Change | Why |
|---|---|
| **Station figures:** `126 / 300 cards programmed` with progress bar, successful cards, failed attempts, skipped cards, elapsed time, average per card (incl. handling), average tag → saved, write and read-back time; session log as **CSV**. | Requested; the CSV is the basis of the hardware test report. |
| **One clear message per failure** (title, what to do, "nothing was saved"): *Tag removed too early*, *Wrong tag type*, *Tag is locked*, *Tag belongs to another active card*, *Write failed*, *Verification failed*, *Server unavailable*, *Network timeout*, *Card already programmed*. | Messages were technical or missing for network problems. |
| **Programming requests time out after 15 s** (`NETWORK_TIMEOUT`); no answer / 5xx → `SERVER_UNAVAILABLE`. | A hanging request stopped the station without any message. |
| **Locked tags are detected before writing** (a 40-byte probe is refused too) → *Tag is locked*. A write that fails right after successful probe writes is reported as *Tag removed too early*. | Both showed a generic write error. |
| **Durations per attempt** (`detect_ms`, `write_ms`, `verify_ms`, `total_ms`) sent by the dashboard and stored in `nfc_write_attempts` (migration `2026_10_02_000001`). | Write / verification / total times can be measured on real devices. |
| **Two phones on one card:** station requests carry `only_if_unprogrammed`; the check and the save (under the row lock) refuse a card that got a tag elsewhere (`NFC_CARD_ALREADY_PROGRAMMED`), and the station moves on by itself. | Two stations starting at the same number silently replaced each other's chips. |
| **A copy of another card's link on a different chip can be reprogrammed** when that card has a verified, different chip (`content: stale_copy`). | Tags written by a station that lost the race above were otherwise unusable. |
| **Retry after a lost answer:** a save that reached the server is recognised on the retry (*already programmed*, never saved twice), and the tag is still locked if locking was requested (`POST /nfc/lock` accepted after `already_programmed`). | The tag stayed unlocked in that case. |
| **Unfinished attempts** of the same user and device older than a minute are closed (`SUPERSEDED`) by the next attempt for the card. | Closed browsers left attempts *in progress* forever. |
| **Rate limit** `nfc-programming`: 180 programming requests per minute per user and device. | The check endpoint could be used to probe chip serials. |
| **Scans:** an NFC tap of a card with a bound chip that arrives **without** a chip serial is refused (`NFC_UID_MISMATCH`, while *Enforce chip binding* is on); opened links (`method: link`) of NTAG 424 DNA cards are verified like taps (SUN MAC, replay counter). | Both apps always send the serial with a tap, so a tap without one is forged; the native app reports iPhone reads of secure cards as `link`, which were not verified. |

## 1.4.0: NFC programming v2 (dashboard)

The dashboard's card-programming workflow is production-ready: a tag is read, checked against the server, written,
read back and verified before its chip is saved, and many cards can be programmed in one session. The waiter app is
unchanged and stays read-only (no file under `waiter-app/` changed). No other product feature was added.

Verification:

- **Backend:** 151 PHPUnit tests (814 assertions), including the new `NfcProgrammingTest` (21 tests); the NFC tests also pass on MariaDB 10.11. Larastan level 8 and Pint clean.
- **Dashboard:** 25 unit tests (`node --test`): the workflow engine against a simulated NTAG213/215/216/424 chip model (`nfc-programming.test.ts`) and the Web NFC driver against a fake `NDEFReader` (`nfc.test.ts`). TypeScript, ESLint, Prettier and `next build` clean.
- **End to end:** new [`e2e/nfc-programming.mjs`](e2e/README.md) (9 steps, Pixel 7 profile, simulated NFC field, axe scan); `pilot-journey.mjs` and `waiter-api.mjs` pass.
- **Not verifiable here:** real tags on real phones. Run the release test in [docs/NFC.md](docs/NFC.md) (*Operational tips*) before rolling out.

| Change | Why |
|---|---|
| **Verified workflow** (`frontend/src/lib/nfc-programming.ts`): read tag → `POST /cards/{id}/nfc/check` → detect chip → write NDEF URL → read back → verify same chip and exact URL → `POST /cards/{id}/nfc` → optional lock → `POST /cards/{id}/nfc/lock`. | Before, the URL was written blind and the UID the browser reported was stored without proof that the write succeeded or that it was the same tag. |
| **Tags of other cards are refused before writing**: the chip is linked to another usable card (any restaurant; details only for your own), or the tag carries the link of another usable card. | Before, `overwrite: true` destroyed another card's tag and the conflict was only noticed afterwards. |
| **The UID is saved only after verification.** The API accepts `uid` only with `method: web_nfc` and the read-back proof (`read_back.uid`, `read_back.url`), which the server compares again. External writer apps (`manual`), NTAG 424 provisioning and QR cards never store a UID; the manual serial-number field is gone. Cards show *Verified* or *Not verified*. | A typed or unverified serial number could bind the wrong chip. |
| **Unique constraint**: generated column `gift_cards.nfc_uid_active` (UID while the card is usable) with a unique index. The NTAG 424 first-tap binding respects it too. | The app-level check could be raced by two stations; now the database guarantees one chip ↔ one usable card. Replaced and expired cards release their chip. |
| **Automatic chip detection** (NTAG213 / 215 / 216) by probing the memory size; NTAG 424 DNA and other Type 4 tags are refused on this path. The *Card type* choice for NFC tags is replaced by *NFC tag · NTAG213 / 215 / 216*. | Web NFC does not report the chip model; the type recorded was whatever the operator selected. |
| **Attempt log**: table `nfc_write_attempts` (one row per attempt: method, last stage, result, error, chip, type, content found, read-back URL, conflict, user, device), `POST`/`GET /cards/{id}/nfc/attempts`, *Tag programming* list on the card page, audit actions `nfc_write_refused`, `nfc_write_failed`, `nfc_locked`, `nfc_lock_failed`. | Only successful binds were recorded. |
| **Programming station** `/cards/program` (*Gift cards → Program NFC tags*): works through every usable card without a tag in card-number order (`GET /cards?nfc_status=unprogrammed&sort=card_number&card_number_after=`), one NFC session for all cards, automatic advance with sound and vibration, the previous tag ignored, *Try again* / *Skip card* / *Stop*, session log, screen kept on. | Programming hundreds of cards one dialog at a time was not practical. |
| **Lock only after verification**, reported separately; a lock error leaves a verified, writable tag. | A tag locked with a wrong or unconfirmed URL cannot be fixed. |
| **Retries are safe**: re-sending a successful bind is idempotent; a tag already programmed and verified for the card is recognised without writing. | Flaky connections at the counter. |

Documentation updated: `docs/NFC.md`, `docs/API.md`, `docs/DATABASE.md`, `docs/SECURITY.md`, `docs/USER_GUIDE.md`, `e2e/README.md`, and the German and BHS manager, onboarding, knowledge-base, security, marketing, business-plan, API and performance documents that described the manual serial-number entry.

## 1.3.0: Native waiter app (GiftCard Waiter)

The native Android and iPhone app specified in [docs/design/waiter-app](docs/design/waiter-app/README.md) is built,
together with the backend it needs. The design documents were not changed; where they disagreed, the resolved
conflicts register (13 §7) and the precedence rules of 09 §1.3 decided. Each entry says **what** and **why**.

Verification:

- **Backend:** 130 PHPUnit tests (623 assertions), Larastan level 8 and Pint clean.
- **Waiter app:** 601 Flutter tests: unit tests of the redeem state machine (idempotency invariants I1–I6), token, format and theme tests, component tests, screen tests for every S01–S17 variant (DE/EN/BHS, 200 % text, iPhone SE size, tablet, dark mode, Reduce Motion), and an end-to-end journey from sign-in to redemption, Recent and sign-out. `flutter analyze` (strict) is clean. The Android release APK builds (arm64: 23.6 MB, within the 25 MB budget).
- **API end to end:** new [`e2e/waiter-api.mjs`](e2e/README.md) plays the app's calls against a running stack (11 steps, redeem 61 ms).
- **Not verifiable here:** the iOS build (needs Xcode on a Mac), real NFC cards, biometrics and the iPhone NFC sheet. Test them on the reference devices (09 §11.3) before the first store release.

### Backend

| Change | Why |
|---|---|
| **`POST /api/v1/auth/token`**: sign-in for the native app. Returns a bearer token that can only scan and redeem, is bound to the phone that signed in, lasts 30 days and is renewed while the phone is used. Signing in again replaces the old token; sign-out revokes it. | Prerequisite 1 of the handoff (09 §9.4). The web sign-in uses cookies, which native apps cannot use safely. |
| **A device token only works with its own `X-Device-Id`** and only reaches `auth/me`, `auth/logout`, `scan`, `cards/{id}/redeem` and `devices/current`, even for owners. Revoking the phone under **Devices** stops it at once (`403 DEVICE_REVOKED`); restoring allows it again. | A copied token is useless on another phone, and a lost phone is switched off where owners already manage devices. |
| **Device tokens are not listed under Settings → API.** | They belong to phones, not to integrations. |
| **Web and app sign-in share one credential check** (`CredentialVerifier`): same lockout, timing protection and account rules. | No channel is easier to attack than another, and the rules exist once. |
| **`401 ACCOUNT_DEACTIVATED`** for the app (sign-in and every request with its token). | The app can say "Account deactivated" instead of a misleading "Session expired" (open question Q2). |
| **`VELOCITY_LIMIT_EXCEEDED` includes `context.retry_after`.** | The app can say when the card can be used again (Q7). |
| **`GET /api/v1/app/config`** (public, cacheable 60 s): minimum app version per platform, maintenance notice, card domains. Platform admins set the minimum versions under **System settings** (validated `1.2.3` format, audit-logged). | Prerequisite 4: old app versions can be retired and maintenance announced. |
| **Universal Links / App Links:** the web app serves `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` from `WAITER_IOS_APP_IDS`, `WAITER_ANDROID_PACKAGE`, `WAITER_ANDROID_CERT_SHA256` (404 while unset). | Prerequisite 3: a card link opens the app on a waiter's phone; everyone else still gets the balance page. |
| **Queue backlog alert:** when `queue:monitor` finds more than 500 waiting jobs, a critical log entry and an e-mail to `OPS_ALERT_EMAIL` (or the support address) go out, at most once per queue every 30 minutes. | The check ran every 5 minutes but nobody was told (monitoring guide). |

### Waiter app (new, `waiter-app/`)

| Area | What |
|---|---|
| Screens | S01–S17 as specified: splash, sign-in, biometrics, unlock, ready (Android NFC reader, iPhone scan button, iPad/no-NFC, offline, NFC off, maintenance, first-card tip), charge and redeeming (all card states, notices, hold-to-redeem from € 100, uncertain outcome), success, problem screens, manual entry, QR scan, Recent, menu, session/account states, update required, intro. |
| Money safety | One idempotency key per card and amount; slow and interrupted redemptions retry with the same key for up to 20 s, then "Try again / Cancel"; never redeems offline; a 401 keeps the attempt across re-sign-in. |
| Platform | Android reader mode (NFC-A, no system sound, 250 ms presence check) and iPhone tag reader session with UID, through the app's own channels; haptics and the four synthesised sounds per the sound spec; Keychain / Keystore storage; biometric unlock with enrolment-change detection; keep screen on; portrait lock on phones. |
| Design system | Tokens generated from `tokens/waiter.tokens.json`; Geist fonts, 46 icons, 10 illustrations, launcher icons and splash; strings imported from the master string table (269 keys in DE/EN/BHS). |
| CI | New GitHub Actions job: generated files up to date, `flutter analyze`, `flutter test`, Android release build. The web app's unit tests (`npm test`) now run in CI too. |

### Documentation

API reference, environment variables, monitoring guide (EN, DE, BHS), README, e2e README and the new
[waiter-app/README.md](waiter-app/README.md). The product FAQ and overview (DE, BHS) now say the native app is
developed but not yet in the stores.

## 1.2.0: Pilot release (first paying restaurant)

No new modules and no redesign. Every screen was used from an **empty database** as each role would use it:
platform admin, owner, manager and waiter. The screens were checked on desktop (1440 px), tablet (iPad), phone
(iPhone 13, Pixel 7) and small phones (360 × 640, iPhone SE with the browser bar). Everything that felt
confusing, slow, ugly or unnecessary was fixed. Each entry says **what** changed and **why**.

Verification:

- **Tests:** 113 PHPUnit tests (513 assertions) on SQLite and MariaDB. Larastan level 8, Pint, ESLint, Prettier, `tsc` and `next build` are clean.
- **Acceptance test:** new [`e2e/pilot-journey.mjs`](e2e/README.md) plays through the restaurant's first day in real browsers. The waiter's redemption took 0.48 s including typing the card number.
- **Accessibility:** axe (WCAG 2.1 AA) finds no violations on any main screen, in light or dark mode.
- **Layout:** no horizontal scrolling on any page at 360 px, 390 px or tablet width.

### Waiter app (the most important screen)

| Change | Why |
|---|---|
| **The balance, card number, status and close button now sit in one compact card.** | This saves a full row. The amount, the keypad and the **Redeem** button now fit on an iPhone SE with the browser bar visible. Before, the Redeem button was pushed below the fold on small phones. |
| **Short screens get a compact layout** (`short:` variant, max-height 740 px): smaller keys, amount and header. | The same reason: a waiter must never have to scroll during service. |
| **A large "Next card" button appears when a card cannot be used** (blocked, expired, replaced, empty). | Before, the only way out was a small ✕ in the corner. |
| **Blocked and replaced cards show a red warning. Inactive and empty cards show an amber one.** "Replaced" now says *Ask the guest for the new card*. | Waiters can tell "do not accept, fraud risk" apart from "just empty" at a glance, and know what to say to the guest. |
| **Friendly scan errors:** *No card with this number. Check the digits and try again.* / *This is not one of our gift cards.* | This replaces the technical "Gift card not found.". |
| **The hint depends on the phone:** iPhone gets the tap-the-top instruction. Android without NFC gets *switch on NFC and use Chrome*. Phones that do support NFC get *Press the button once, after that cards are read as soon as they are tapped.* | Before, Android phones showed the iPhone instructions. |
| **Block reasons can be chosen with one tap** (Reported stolen, Reported lost, Suspicious use). | Fewer taps, and the audit log gets consistent reasons. |

### Owner dashboard

| Change | Why |
|---|---|
| **The four KPIs are now the numbers an owner asks about:** Outstanding balance (*Open liability on N cards*), Revenue this month (with the change vs. last month), **Redeemed this month** (*€ X today*), Cards sold (*N this month · N in use*). | "Transactions today" (a count that included internal transfers) is gone, and redemptions now have their own card. "0 redeemed" (fully used cards) confused everyone. |
| **New API field `outstanding_cards`.** | This is the number behind the liability wording. |
| **A Welcome panel for a new restaurant:** check card rules → invite the team → issue the first card → open waiter mode. It is permission-aware and disappears after the first sale. | An empty dashboard gave a new owner no idea where to start. |
| **Charts without data show a calm "No sales in this period" panel** instead of an axis of five "€ 0" ticks. | The empty charts looked broken. |
| **Daily sales vs. redemptions is now a bar chart** instead of a smoothed line. | A smoothed line through mostly-zero days drew fake slopes, suggesting sales on days with none. Bars show the real days. |
| **Charts load after the KPIs** (`next/dynamic`). The dashboard's first-load JS dropped from 251 kB to 142 kB. | The numbers appear first and the page feels faster, especially on phones. |
| **The period switch (7d/30d/90d) is a real segmented control** (a radio group). | Tabs without panels produced invalid ARIA, which axe flagged as critical. |

### Card management

| Change | Why |
|---|---|
| **Phone layout for the card list:** the number with the customer below it on the left, the balance with the status on the right. Transactions, team, admin restaurants and the audit log follow the same pattern. | Tables used to scroll sideways on phones and hid the status and balance. |
| **The card detail header wraps cleanly** on phones and tablets, and the card visual keeps a sensible width. | On an iPad the Redeem / Reload / ⋯ buttons stacked vertically and the status badge was clipped on phones. |
| **"Total loaded" became "Reloaded"**, which shows only the reloads. "Total redeemed" became "Redeemed". | "Total loaded € 45" next to "Initial value € 25" read as a bookkeeping error, because the sale was counted twice. |
| **Replacement notes use the printed number format**: *Replacement for 7666 5628 6896 4312*, *Replaced by …: Lost*. "Replaces" / "Replaced by" links are formatted the same way. | 16 digits without spaces could not be read. |
| **Replace and reverse offer one-tap reasons** (Lost / Damaged / Stolen, Wrong amount / Wrong card / Guest cancelled). Ctrl/⌘+Enter confirms. | Replacing a lost card no longer needs any typing. |
| **"No matching cards" has a Clear filters button.** | The obvious next action was missing. |
| **New card:** amount chips read **€ 50** instead of € 50,00 (also the value limits). The customer switch fits on phones. Labels are connected to their fields. | Easier to read, and the switch no longer overflows on phones. |
| **NFC dialog:** the card type shows its name only, with descriptions in the list. The lock option sits full width. The chip serial number has a short explanation below the field. | The select text was cut off ("504 bytes · recommend…") and the labels wrapped over three lines. |
| **The print layout is in the restaurant's language** (Gutschein, Gültig bis, scan hint). It adds a Back to card link and clearer print instructions. | Guests in Austria received English cards. |
| **Transaction type "Issued" became "Sale"**, in the UI and in exports. | It reads like the other types (Redemption, Reload) and matches how owners talk. |
| **Exports use readable names** for card status and transaction type (*Active*, *Sale*) instead of `active` / `issue`. | The CSV goes straight to the bookkeeper. |
| **The transaction date filters have visible From / To labels** and cannot be set in the wrong order. The layout works on phones. | The unlabelled date fields were ambiguous. |

### Consistency and copy

| Change | Why |
|---|---|
| **New devices are named after their hardware and browser** (*iPhone · Safari*, *Mac · Chrome*) instead of *Device · Maria Huber*. | The person is shown separately, so the history read "Maria Huber · Device · Maria Huber". |
| **Audit log in plain language:** *Password set via e-mail link*, *Card replaced*, *Cloned card rejected*… Fraud events are marked in red with a shield icon. | Title-cased keys such as "Password Reset / Auth" meant nothing to an owner, and security alerts were hidden among routine events. |
| **One user status vocabulary everywhere:** Invited → Active, Locked, Deactivated. | The admin page said "Active" for people who had never accepted their invitation. |
| **The guest balance page is entirely in the restaurant's language**, including the status (*Gültig*, *Vollständig eingelöst*…) and the "not found" page. | It used to mix a German page with an English "Active" badge. |
| **E-mail templates are sorted in the restaurant's language first, then in the order a guest receives them.** The subject preview shows the real restaurant name. | The list was alphabetical by key and showed `{{ restaurant_name }}`. |
| **Sentence case for settings labels** (Default plan, Support e-mail). Brand "colour" became "color", and the card number prefix got a hint. | Consistent American English and consistent capitalisation. |
| **The acting banner reads** *Viewing Gasthaus … as platform administrator.* | It had stray spaces around the restaurant name. |
| **Revoking a device asks for confirmation.** | One mis-tap could lock a waiter out in the middle of service. |
| **Loading buttons show a spinner** instead of "Working…". | Consistent with every other button. |

### Accessibility

| Change | Why |
|---|---|
| **Green amounts use emerald-700 and warnings use amber-700** in light mode. | emerald-600 on white was 3.65:1, below the WCAG AA minimum of 4.5:1. |
| **Audit rows expand through a real button** with `aria-expanded`. | `aria-expanded` on a table row is invalid. |
| **Every select has a label** (audit filter, role, language, card type). | Screen readers announced "button". |

### Documentation

- **New [User guide](docs/USER_GUIDE.md)**: one page each for waiter, manager and owner, with screenshots. It is meant for staff training.
- **New [Pilot checklist](docs/PILOT_CHECKLIST.md)**: before, during and after the first restaurant goes live.
- **New screenshots** in `docs/screenshots/`, taken from a fresh install. The README now has a gallery and the empty-platform quick start.
- **Updated guides:**
  - INSTALLATION: first-restaurant flow, and how to resend an owner invitation.
  - API: `outstanding_cards` and readable exports.
  - DATABASE: what `total_loaded` means.
  - DEVELOPMENT: the acceptance test.
  - FOLDER_STRUCTURE.
- **New test file `PilotReadinessTest`** (4 tests): liability KPIs, device names, replacement notes, readable exports.

---

## 1.1.0: Hardening release (audit, pentest, polish, readiness)

This release adds no new modules. It audits every file of the gift card system and fixes what was found:
money rules, security, waiter speed, UX details and operational readiness. Each entry states **what** changed
and **why**.

Verification for this release:

- **Tests:** 109 PHPUnit tests (498 assertions), green on SQLite and on MariaDB.
- **Static analysis and style:** Larastan level 8 is clean. Pint, ESLint, Prettier, `tsc` and `next build` are clean.
- **Concurrency pentest:** a live run against MariaDB with real row locks. Results are in the pentest table below.
- **End-to-end:** a Playwright walkthrough in a real browser covers onboarding through to the CSV export, with no console errors.

---

### Money and ledger correctness

| Change | Why |
|---|---|
| **Expiry dates follow the restaurant's timezone.** "Valid until 31.12." means 23:59:59 on 31.12 in Vienna, stored as UTC. Before, the date was cut off at midnight UTC. | Previously a card in Austria expired 1–2 hours early, while the restaurant was still open. That is lost money and an angry guest at the till. |
| **"No expiry" and "use the default" are two separate choices.** If `expires_at` is omitted, the restaurant's default validity applies. An explicit `null` means the card never expires. | Before, both cases were treated the same, so a restaurant could not sell a card without an expiry date once it had a default. This matters in Austria, where long expiry periods are the legal norm. |
| **The default validity uses `addMonthsNoOverflow`.** It is computed in local time. | A card sold on 31 August with 3 months' validity now expires on 30 November, not on 1 December. |
| **Editing a card's expiry uses the same end-of-day logic.** Past dates are rejected. | Creating and editing a card now behave the same way. |
| **Replacing an inactive card keeps the new card inactive.** No zero-amount ledger rows are written when the balance is 0. | Replacing a card that had not been sold yet used to activate the new one, which could release an unpaid card. Empty `0,00 €` rows also cluttered the history and exports. |
| **Transfers are only allowed from active or blocked cards.** | Money could be moved off an *expired* or *replaced* card, which bypassed the expiry write-off. Blocked cards are still allowed, because a stolen card must be emptied onto its replacement. |
| **Nightly expiry isolates each card.** A card that fails is reported and skipped. A card that another request expired in the meantime is ignored. | Before, one bad row stopped the whole batch, and every card after it stayed spendable past its expiry. |
| **The dashboard's "expiring soon" only counts cards with a balance.** | Empty cards that are about to expire don't need any action. Counting them made the number meaningless. |
| **The monthly revenue chart is one grouped query per timezone offset.** Before, it ran 12 queries. Day and month buckets are in local time on MySQL, PostgreSQL and SQLite. | This is faster. It is also correct: a sale at 00:30 Vienna time now counts on the right day. |
| **CSV exports use a decimal comma for German locales** (`24,90`). The CSV sanitizer leaves plain numbers alone. | Austrian Excel opened `24.90` as a date or as text, so bookkeepers had to fix every export by hand. The formula-injection guard used to prefix negative amounts like `-12,50` with `'`. |

### Security (pentest findings)

| Change | Why |
|---|---|
| **A session is pinned to the device it signed in on.** The fingerprint of `X-Device-Id` is stored in the session. If it doesn't match, the session is logged out with a 401. | A session cookie copied from a waiter's phone could otherwise be used from any device, which made revoking that phone useless. |
| **UID mismatches, invalid SUN signatures and NFC replays count towards the scan lockout.** Only "not found" used to count. | An attacker with a cloned card could otherwise retry without any limit. |
| **Suspicious scans and account lockouts go to the application log as `warning`**, in addition to the audit tables. | Operators can now alert on cloned or replayed cards and on brute-force attempts. Before, these events were only in database tables that nobody watches at night. |
| **The failed-login counter is incremented atomically** (`increment()`). | Parallel wrong-password requests could overwrite each other and never reach the lockout threshold. |
| **Re-binding the same NFC chip keeps its replay counter.** The counter is only reset when a different chip is bound. Binding a 424 tag without a UID keeps the known UID. | Re-writing a card used to reset the counter to 0. That made every earlier tap valid again, which is exactly the replay attack the counter exists to stop. |
| **`nfc_uid` in scan requests is validated** as 4, 7 or 10 bytes of hex. | Arbitrary strings reached the UID comparison and the scan log. |
| **Idempotency keys: `:` is reserved for internal ledger legs.** POST `/cards` accepts an optional key. The maximum length is 96 characters, the same as the column. | A client key ending in `:in` could collide with the internal transfer-in leg. Card creation could also be doubled by a network retry. Longer keys used to fail at the database level with a 500. |
| **Staff never get a password by e-mail or from a colleague.** Invitations are a one-time link to "set your password", valid for 72 h. They use a separate token broker from the 60-minute password reset. "Reset password" for a user who never signed in re-sends the invitation. | This follows the security principle, and it is also better UX. The old flow sent a normal reset link, which expired after 60 minutes and was usually already dead when a new waiter opened it the next day. |
| **Invitation, reset and card e-mails are sent exactly once.** | Laravel's event discovery registered the listeners a second time on top of the manual `Event::subscribe`, so every event was handled twice. Guests got two "your gift card" e-mails, and audit entries were duplicated. |
| **No personal data in the audit log.** Changes to customer names, e-mail, phone, notes or recipient names are logged as `[personal data]`. Anonymising a customer also scrubs their address from the notification log. | Under GDPR, erasure has to be complete. Before, a customer's old e-mail address stayed in the immutable audit log for ever, which made the right to erasure impossible to fulfil. |
| **CORS is explicitly disabled** (`config/cors.php`). | The app is same-origin by design. Laravel's default CORS config would have allowed any origin on `api/*` if someone later enabled the middleware. |
| **`TrustProxies` is limited to private network ranges** instead of `*`. | With `*`, any client could set `X-Forwarded-For` and bypass the per-IP login and scan throttles, and forge IPs in the audit log. |
| **The public balance page returns 404 for closed restaurants.** | Soft-deleted restaurants used to leak their name and card balances through old QR codes. |
| **Removed the useless `DB::table('sessions')` deletes.** Session invalidation after a password change goes through `AuthenticateSession`. | Sessions are stored in Redis, so the deletes did nothing and gave a false sense of security. |
| **`/up` checks the database and cache**, via a `DiagnosingHealth` listener. | Before, `/up` returned 200 even when MySQL was down, so uptime monitoring and the deploy health check could not detect an outage. |
| **API tokens record `last_used_ip`.** | The column existed but was never written. It is needed to spot a leaked POS token. |
| **The login redirect after sign-in only allows same-site paths** (`safeRedirectPath`). | `?redirect=//evil.example` was an open redirect that could be used for phishing staff. |
| **Lazy-loading and silently discarded attributes throw outside production.** | This catches N+1 queries and typos in `fill()` during development, before they reach a restaurant. |

### Concurrency pentest (MariaDB, real row locks, `PHP_CLI_SERVER_WORKERS=10`)

| Scenario | Result |
|---|---|
| A: 20 parallel redemptions of €5 on a €30 card | 6 succeeded and 14 were rejected. Balance €0, and the ledger sum matches. |
| B: parallel reloads close to the maximum balance | Capped exactly at `max_card_balance`. |
| C: 8 parallel replacements of one card | 1 succeeded and 7 were rejected. There is exactly one successor. |
| D: redemptions racing a replacement | The money is either redeemed or moved, never both. The sum is consistent. |
| E: 10 requests sharing one idempotency key | 1×201 and 9×200 (replayed). Exactly one ledger row. |
| F: opposing transfers A→B and B→A | No deadlock, thanks to the deterministic lock order. Balances are conserved. |
| Brute force, forged UUIDs, cross-tenant IDs, SQLi/XSS payloads in search and notes, expired, blocked or replaced cards, deactivated users, suspended restaurants | All rejected with the correct error code and no 500s. Covered permanently by the feature tests (`TenantIsolationTest`, `PermissionsTest`, `CardScanTest`, `AuthenticationTest`, `HardeningTest`). |

The pentest showed that the 60/min per-user limit could block a busy waiter who uses two terminals. As a result, **`card-scan` and `card-operation` are now 90/min per user *per terminal*.** Brute-force protection is unaffected, because failed scans are throttled separately per user and per IP.

### Waiter flow (goal: under 5 seconds)

Measured in E2E: card lookup takes **92 ms**, and the full UI flow (tap → amount → redeem → done) takes **545 ms**.

| Change | Why |
|---|---|
| **The NFC reader no longer restarts on every render**, because it uses a stable `mutateAsync` reference. | The scanner was torn down and started again on every keypress. Taps during that gap were lost, so the waiter had to tap two or three times. |
| **NFC keeps listening on the success screen.** "Or simply tap the next card" | The next guest's card can be tapped right away without pressing "Done". This saves one step per guest. |
| **The terminal opens on the action that is actually possible.** For example, "Reload" for an empty card. | Before, it offered "Redeem" on a €0 card, and the waiter had to switch. |
| **Removed the keypad cap at the balance. A clear hint now says "More than the balance…"** | The keypad used to silently ignore digits, which looked like a broken phone. |
| **An opened `/c/{token}` link is replaced by `/waiter` in the browser history.** | Pressing back or reloading re-opened the old card. A waiter could then redeem on the previous guest's card. |
| **`aria-live` on the amount and the result, `aria-pressed` on the mode buttons, a clearer header ("Gift card").** | Screen reader support, and less visual noise on a small screen. |
| **Hydration-safe capability detection** (`useSyncExternalStore`) for Web NFC and the QR camera. | Removes a React hydration warning and a layout flicker when the terminal opens. |

### UX polish (no redesign)

| Change | Why |
|---|---|
| **One source for regional formatting** (`lib/regional.ts`): locale, timezone and currency symbol come from the restaurant. The money input uses the local decimal separator and the € symbol. | Dates and amounts used to follow the browser. A German-speaking waiter on an English phone saw `24.90` and US dates. |
| **Date inputs: tomorrow is the earliest allowed date.** The default expiry never overflows the month. A "no expiry" hint is shown. | Choosing today or a past date gave a server error after submitting. |
| **Card numbers use tabular figures with letter spacing** (`.card-number`) instead of a monospace font. | Easier to read aloud at the till, and it matches the rest of the typography. |
| **Consistent card spacing. Settings forms no longer need padding hacks** (`<form className="contents">`). | Removed layout workarounds and made spacing even across all settings pages. |
| **Dashboard:** 2-column stat grid on phones, responsive stat sizes, "Transactions today" wording. | Owners mostly check the numbers on their phones. |
| **Card history:** the reverse button is visible on touch devices and amounts are aligned. | Hover-only actions were impossible to reach on a tablet. |
| **Card detail:** "Not written yet" is now a direct "Write now" action that opens the NFC dialog. | Saves a detour for a task that has to be done for every new card. |
| **Names in the customer and admin tables are real links.** | Keyboard and screen-reader users can now open rows. |
| **Timezone picker instead of a free text field.** | Typos like `Europe/Vienna ` broke every date calculation for that restaurant. |
| **Devices can be renamed** in the list. | "iPhone (Safari)" ×4 is useless when a phone gets lost. The API already supported renaming. |
| **Platform notice banner** (maintenance message and support e-mail) in the app and the waiter terminal. | These settings existed but were never shown. |
| **Invitation screen:** "Welcome to GiftCard Pro, choose your password". The team page shows an "Invited" badge and a "Resend invitation" button. | New staff understood a "reset password" page as an error. |
| **Network errors show "No connection to the server…"** instead of `TypeError: Failed to fetch`. | Waiters are on restaurant Wi-Fi, so they need to understand the message. |
| **The CSRF cookie is prefetched on app start.** | Removes a round-trip from the first money action. |

### Code quality and simplification

| Change | Why |
|---|---|
| **Removed dead columns and permissions:** `restaurants.logo_path`, `restaurant_settings.extra`, `devices.supports_web_nfc`, and the `reports.view` permission. The migrations, models, resources, factory and TS types were updated with them. | They were never read or written anywhere. Dead schema invites wrong assumptions. |
| **Removed the dead `CardNotificationService::alreadySent()`, the manual listener registration and unused system settings** (`platform.name`, `allow_self_signup`). | Less code to maintain. The settings had no effect. |
| **`CardHistoryService` returns a plain list with microsecond timestamps** and hides the internal `balance_transferred` audit event. | Correct ordering of entries within the same second. The history no longer shows a transfer twice. |
| **`CardScanService`:** a shared `hit()` helper and a simpler `fail()` signature. The UID is truncated to the column size. | Removes duplicated throttling code and a possible 500 on very long UIDs. |
| **The idempotency middleware** exposes its request attribute as a constant and supports `idempotent:optional`. | Controllers used to repeat the string key. Adding optional mode to the existing middleware avoided a second one. |
| **Shared date-filter helpers in the base controller** (`dayStart`/`dayEnd` in restaurant time). | Card, transaction and audit filters each did their own UTC conversion, and all of them were wrong by 1–2 hours. |
| **Seeders use `config()` instead of `env()`, and the demo seeder follows the new expiry API.** `RolesAndPermissionsSeeder` fails loudly when it is misconfigured. | `env()` returns null once the config is cached in production, so demo data would silently be seeded or not seeded at all. |
| **The new-restaurant plan comes from `platform.default_plan`.** | The system setting existed but was ignored. |
| **Friendlier validation messages** when onboarding a restaurant (`owner.email` → "owner e-mail"). | These messages are shown directly to platform admins. |
| **PHPStan raised to level 8**, with all findings fixed. These included a private static trait method, return types, `$this` in static closures, and loose `findOrFail` IDs. | Stricter typing catches real bugs, for example nullable money values. |

### Operations and restaurant readiness

| Change | Why |
|---|---|
| **The scheduler runs in `SCHEDULE_TIMEZONE`** (default Europe/Vienna). Expiry runs at 00:15, reminders at 10:00 and cleanup at 03:30 local time. | Before, the jobs ran at UTC times. Reminder e-mails went out at 11:00 or 12:00 depending on daylight saving time, and expiry could run while guests were still paying. |
| **Expiry reminders are sent only for active restaurants.** | Suspended or closed restaurants were still e-mailing their guests. |
| **`queue:monitor` only runs when the queue driver is Redis.** | It errored every 5 minutes on development setups. |
| **Docker: the queue and the scheduler wait for a healthy `api`** (after migrations). `migrate --isolated` prevents parallel migrations. | Workers could start processing jobs against an old schema during a deploy. Two app replicas could run the same migration at the same time. |
| **CI:** removed `--parallel`, because paratest is not installed. | CI would have failed on the first run. |
| **`.env` examples:** `SCHEDULE_TIMEZONE`. `LOG_LEVEL=debug` locally (the `log` mailer writes e-mails at debug level). `LOG_CHANNEL=null` in tests. | Local invitation and reset links were invisible with `info`. Tests no longer write log files. |
| **Docs updated:** API (expiry semantics, idempotency, rate limits, invitations), SECURITY (new controls), ENVIRONMENT, DATABASE, DEPLOYMENT (nightly jobs, monitoring and alerts), DEVELOPMENT (test suites, pentest scenarios, static analysis). | The docs must match what is shipped. |

**Restaurant readiness E2E (Playwright, real browser), all 8 steps pass:**

1. The platform admin onboards a restaurant.
2. The owner receives the invitation, sets a password and sees the dashboard.
3. The owner invites a waiter.
4. A card is created and marked as written.
5. The waiter redeems €24,90 in 545 ms.
6. The history shows the redemption, and the card is replaced with the NFC dialog open.
7. The old card is shown as replaced and cannot be used.
8. The CSV export opens correctly with a decimal comma.

### Tests added

- **`HardeningTest`** (15 tests) covers:
  - timezone expiry, and null versus missing expiry;
  - replacing an inactive card, and no zero ledger rows;
  - no transfers from inactive cards;
  - the replay counter surviving a re-bind;
  - optional idempotency on create, and the key format;
  - session↔device pinning;
  - closed restaurant hidden;
  - exactly one e-mail per event;
  - no PII in the audit log, and anonymisation scrubbing the notification log;
  - invalid `nfc_uid`;
  - the `/up` health check;
  - CORS off;
  - CSV decimal comma.
- **`StaffManagementTest`:** a 72 h invitation versus a 1 h password reset.
- **`CsvSanitizerTest`:** numbers pass through, formulas are still neutralised.
