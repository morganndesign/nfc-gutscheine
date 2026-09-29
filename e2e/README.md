# Acceptance test — pilot journey

`pilot-journey.mjs` plays through the first day of a new restaurant in real browsers (desktop for the owner,
a Pixel 7 for the waiter) and fails on any broken step, console error or accessibility violation:

1. platform admin onboards a restaurant, 2. owner accepts the invitation, 3. invites a waiter,
4. sells a printable voucher (cash) and checks the sheet carries no voucher number, 5. the waiter scans its QR
on the phone and redeems (must take < 5 s; camera and QR detection are simulated), 6. owner reloads and blocks
the voucher, 7. the waiter's next scan shows it blocked, 8. CSV export (decimal comma), 9. axe accessibility scan.

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
address, lets the owner accept, disables/enables, archives/restores, checks that a restaurant with vouchers
cannot be deleted (with the demo data) and deletes the empty one after the typed confirmation, filters the
audit log and scans the admin screens with axe. It checks the delivered or (with `MAIL_MAILER=log`) "not delivered" behaviour, whichever the API reports.

# Waiter app API — `waiter-api.mjs`

Plays the calls of the native waiter app (GiftCard Waiter) against a running API: start-up config, device-bound
token sign-in, `/auth/me`, a voucher number refused as a credential, a QR presentment, redeem with an idempotent
replay, the single use of the presentment, the token's limits, device revocation and sign-out. Needs only Node 22 (no browser).

```bash
cd e2e
API_URL=http://localhost:8000 npm run test:waiter-api
```

| Variable | Default |
|---|---|
| `API_URL` | `http://localhost:8000` |
| `WEB_ORIGIN` | `http://localhost:3000` (must be in `SANCTUM_STATEFUL_DOMAINS` for the owner's session) |
| `OWNER_EMAIL` / `WAITER_EMAIL` / `PASSWORD` | demo owner and waiter of Bella Vista |
