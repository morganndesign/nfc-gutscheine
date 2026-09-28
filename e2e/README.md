# Acceptance test — pilot journey

`pilot-journey.mjs` plays through the first day of a new restaurant in real browsers (desktop for the owner,
a Pixel 7 for the waiter) and fails on any broken step, console error or accessibility violation:

1. platform admin onboards a restaurant, 2. owner accepts the invitation, 3. invites a waiter,
4. sells a card, 5. the waiter redeems on the phone (must take < 5 s), 6. owner reloads and replaces the
"lost" card, 7. the old card is rejected, 8. CSV export (decimal comma), 9. axe accessibility scan.

```bash
# API (default MAIL_MAILER=failover: Mailpit if running, else the log), web app on :3000, a platform admin exists
cd e2e
npm install && npx playwright install chromium
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

| Variable | Default |
|---|---|
| `BASE_URL` | `http://localhost:3000` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | demo admin |
| `MAILPIT_URL` | `http://localhost:8025` (invitation links are read from Mailpit first) |
| `LARAVEL_LOG_DIR` | `../backend/storage/logs/` (… or from the log when Mailpit is not running) |
| `CHROMIUM_PATH` | Playwright's own Chromium |

Each run creates a new restaurant with unique addresses, so it can run repeatedly against the same database.

# Platform administration — `platform-admin.mjs`

`npm run test:admin` (same requirements as the pilot journey): onboards a restaurant, checks the list columns
(Restaurant · Owner · Email · Status · Created · Actions), edits it, sends the invitation again with a corrected
address, lets the owner accept, disables/enables, archives/restores, checks that a restaurant with gift cards
cannot be deleted (with the demo data) and deletes the empty one after the typed confirmation, filters the
audit log and scans the admin screens with axe. It checks the delivered or (with `MAIL_MAILER=log`) "not delivered" behaviour, whichever the API reports.

# Waiter app API — `waiter-api.mjs`

Plays the calls of the native waiter app (GiftCard Waiter) against a running API: start-up config, device-bound
token sign-in, `/auth/me`, scan, redeem with an idempotent replay, the token's limits, device revocation and
sign-out. Needs only Node 22 (no browser).

```bash
cd e2e
API_URL=http://localhost:8000 npm run test:waiter-api
```

| Variable | Default |
|---|---|
| `API_URL` | `http://localhost:8000` |
| `WEB_ORIGIN` | `http://localhost:3000` (must be in `SANCTUM_STATEFUL_DOMAINS` for the owner's session) |
| `OWNER_EMAIL` / `WAITER_EMAIL` / `PASSWORD` | demo owner and waiter of Bella Vista |

# NFC programming — `nfc-programming.mjs`

Programs tags in a real browser (Pixel 7 profile) through the dashboard's **Program NFC tags** station and the
single-card dialog. Chromium has no NFC hardware, so `window.NDEFReader` is replaced by a simulated field with
NTAG213 / NTAG215 / NTAG216 / NTAG 424 tags that behaves like Chrome on Android (the tag stays connected while held,
writes larger than the chip memory fail with `NetworkError`, a new scan delivers the tag on the phone). In one station
session without reload it checks all three chip types, write → read back → verify → save → lock, the previous tag being
ignored, and recovery with **Try again** from: a tag of another active card, an NTAG 424 (wrong tag type), a locked tag,
a tag removed during the write, the server being unreachable, a failed verification and a 15-second network timeout
(saved exactly once). Then the progress and statistics, the same tag programmed twice, redemption after a chip read,
clone and missing-serial rejection, the complete attempt log (nothing left *in progress*) and an axe scan. It prints
the measured detect / write / verify / total times — of the simulation, not of real hardware (takes ~1 minute).

```bash
cd e2e
npm run test:nfc        # same requirements as pilot-journey.mjs
```

The simulation cannot replace the release test with real tags on real phones: [docs/NFC-RELEASE-TEST.md](../docs/NFC-RELEASE-TEST.md).
