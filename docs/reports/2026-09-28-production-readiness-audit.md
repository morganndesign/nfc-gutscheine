# Production readiness audit — 28 September 2026

Scope: the whole product at commit `c9de5bd` (+ Mailpit change of the same day): Platform Admin, Restaurant
Dashboard, web waiter terminal, NFC programming station ("NFC write app"), GiftCard Waiter (Flutter, Android +
iOS), backend API, NFC security, deployment on Coolify, backup and recovery.

Method: every critical journey was run end to end against a local stack (real browsers, real mail via Mailpit);
the full automated suites were run; five independent reviews (security, money/NFC, mobile, web UX/a11y,
operations) read the code for concrete, evidenced defects; the most consequential claims were re-verified by hand
(marked ✔ below). **Verdict: not production ready.** 5 Critical and 17 High issues must be resolved first.

## 1. What was tested

| Journey / suite | Result |
|---|---|
| Platform admin: onboard → invitation (German e-mail in Mailpit) → list → edit → invite again with corrected address → owner accepts → disable/enable → archive/restore → delete refused with cards → delete empty → audit filter → axe | ✅ `e2e/platform-admin.mjs`, 10 steps |
| Pilot day: onboard → owner accepts → invites waiter → sells card → waiter redeems on phone (0.75 s) → reload → replace lost card → old card rejected → CSV export → axe | ✅ `e2e/pilot-journey.mjs`, 9 steps |
| Waiter app API: config → device-bound sign-in → scan → idempotent redeem replay → token limits → device revoke/restore → sign-out | ✅ `e2e/waiter-api.mjs`, 11 steps |
| NFC programming station (simulated NFC field): 10 cards, 7 failure classes recovered, lock, clone rejected, redeem with chip | ✅ `e2e/nfc-programming.mjs` |
| Backend PHPUnit | ✅ 207 tests, 1 488 assertions (SQLite) |
| Dashboard typecheck / lint / unit tests / production build | ✅ / ✅ / 32 / ✅ |
| Accessibility (axe, WCAG 2.1 A/AA) on 25 pages as owner, admin, guest | ✅ 0 violations except the two contrast issues below |
| Cross-tenant IDOR probing with a second tenant's owner (cards, sub-routes, customers, transactions, users, devices, reverse, anonymize) | ✅ all 404 |
| Waiter app Flutter tests | ⚠ not run here (no Flutter SDK in the audit environment); last run 626 passing |
| Real NFC hardware, real phones, iOS build, TestFlight, Play internal track | ❌ never done — launch requirement (section 6) |

## 2. Launch-readiness scores

| Area | Score | Why not higher |
|---|---|---|
| Backend API | **72 %** | Ledger, locking, tenancy, audit are solid and well tested; idempotency race (C2), illegal expiry default (C1), irreversible manual expiry, admin token backdoor |
| Platform Admin | **78 %** | Complete CRUD, invitations, diagnostics, e2e-tested; no MFA, admin API tokens unrevocable |
| Restaurant Dashboard | **72 %** | All journeys work and are accessible; transfer-all bug, errors shown as "no data", ambiguous-retry double booking, English-only staff UI |
| Waiter App | **58 %** | Well structured, 5 languages; double-charge paths (C2, C3), no crash reporting, iOS update dead end, never built for iOS nor tested on real phones |
| NFC Write App (programming station) | **70 %** | Robust in simulation incl. failure recovery; never tested with real tags/phones, tags unlocked by default |
| Mobile UX | **66 %** | Keypad and flow good; tap targets < 44 px in the web terminal, slow-network start-up block, uncertain-state handling |
| Security | **62 %** | No cross-tenant access, strong session/CSRF/headers; no MFA, remember-me defeats device revocation, anti-clone bypass via QR/manual, tokens in access logs |
| Performance | **70 %** | Indexed hot paths, paginated, fast (redeem 0.75 s incl. typing); production server undersized (2 GB, no swap) and builds on the same box |
| **Overall product** | **62 %** | Core product is real and works end to end; money-safety, legal and operational blockers remain |

## 3. Critical (launch blockers)

**C1 — Cards expire after 3 years by default and the write-off is irreversible (legal) ✔**
`database/migrations/2026_01_01_000001_create_platform_tables.php:42` (`default_validity_months` 36) applied in
`GiftCardService::issue`; `expire()` books the whole balance as `expiration`; reversal, extension and unblocking of
an expired card are refused. In Austria vouchers are generally valid for 30 years (OGH 7 Ob 22/12d voided a 2-year
clause); every AT tenant would write off customer money at 00:15 automatically.
Fix: default no expiry (or 30 years), require a reason for shorter validity, add an owner-only "reinstate expired
balance" correction. Legal review of the default.

**C2 — A retried redeem can be told "nothing was booked" although the first attempt booked it ✔**
Waiter app retries a slow redeem after 8 s with the same key (`waiter-app/lib/core/state/loop_controller.dart:568`).
The server looks up the key only before locking the card (`GiftCardService::idempotent`, line ~821); the retry waits
for the lock, then fails `CARD_NOT_REDEEMABLE`/`INSUFFICIENT_BALANCE` instead of replaying. The app treats the 4xx as
final ("Es wurde nichts gebucht") → guest pays twice.
Fix: re-check the key under the card lock (return the replay); app treats any 4xx after an unanswered attempt as
uncertain.

**C3 — After an uncertain redeem, staff can book a second redemption; the server offers no way to check**
App: "Cancel" on an uncertain redeem, then changing the amount creates a new key (test asserts this).
Dashboard: after a network error the amount stays editable; `IDEMPOTENCY_CONFLICT` rotates the key
(`components/waiter/terminal.tsx:169`, `components/cards/money-dialog.tsx:67`). Waiter tokens cannot read card
history; no lookup by idempotency key.
Fix: lock amount/operation after an ambiguous failure until the card is re-scanned; return recent transactions (or
the last attempt's outcome) with the scan; warn on same card + amount within 2 minutes.

**C4 — Production server (2 GB, no swap) runs out of memory under load and during every deploy**
Budget estimate: ~1.9 GB idle, 3.5 GB+ under load (php-fpm `pm.max_children = 24` × `memory_limit 256M`, MySQL 512M
buffer pool, Coolify itself), plus 1–2 GB for builds on the same host. The OOM killer typically kills mysqld → full
outage; a kill during a migration can leave a half-applied schema. `docs/DEPLOYMENT.md` itself requires ≥ 4 GB.
Fix: ≥ 4 GB (CX32) + 2–4 GB swap, `pm.max_children` 6–8, per-service memory limits.

**C5 — No off-site backup**
Daily dumps are written to a volume on the same disk; the off-site copy exists only as a suggestion in the docs.
Server or disk loss = every card balance (money owed to guests) is gone.
Fix: encrypted dumps to a Hetzner Storage Box/S3 from the backup container, freshness alert, Hetzner snapshots.

## 4. High

| # | Issue | Evidence | Fix |
|---|---|---|---|
| H1 | Transfer sends the **whole balance** when the amount is unparseable ("." or "abc") ✔ | `components/cards/transfer-dialog.tsx:33` (`null` = full balance); transfers are not reversible | Invalid input disables the button; `null` only for an empty field |
| H2 | Manager can irreversibly expire any card at any time ("delete balance") | `routes/api.php` `cards/{card}/expire`; no undo | Only when due; otherwise owner + reversible entry |
| H3 | NFC anti-clone checks skipped for `qr`/`api`/`manual`/`link` without UID; redeem not tied to a scan | `CardScanService.php:73`; `CardScanTest.php:143` asserts the bypass | Per-card "chip required" (default for NTAG 424); scan nonce required by redeem |
| H4 | "Remember me" (on by default) defeats device pinning; revoking a device does not end browser sessions ✔ | `login/page.tsx:30`, `TrackDevice.php:62`, `DeviceService.php:85` | Bind remember cookie to device; rotate remember token/sessions on revoke; default off |
| H5 | Platform-admin API tokens have `restaurant_id = null` → cannot be listed or revoked (backdoor after session hijack) | `ApiTokenService.php:28`, `ApiTokenController.php:26` | Refuse tokens for tenant-less users; admin token list/revoke |
| H6 | No MFA / step-up for platform admins and owners | — | TOTP/WebAuthn for admin & owner; step-up for tokens, user management, reversals |
| H7 | No error tracking anywhere (API, dashboard, waiter app) and no alerting | no Sentry/Flare; app has no `FlutterError.onError` | Sentry (or self-hosted) for all three; uptime check on `/up`; disk/memory alerts |
| H8 | Worker/scheduler health checks always pass (pgrep matches its own shell) ✔; failed jobs never alerted; backlog alert only > 500 | `docker-compose.coolify.yml` worker/scheduler healthchecks | Heartbeat key written by the worker; `Queue::failing` alert; oldest-job age alert |
| H9 | Backup failure is silent and old dumps are deleted regardless | backup loop `find -mtime +14 -delete` runs after a failed dump | Prune only after success; retry; heartbeat on success |
| H10 | Failed migration → restart loop of all Laravel containers, no pre-migration dump | `infra/docker/php/entrypoint.sh` | Dump before migrate; migration failure fails the deploy instead of looping |
| H11 | Every deploy = 20–90 s downtime; auto-deploy on push to `main` during service hours | Compose recreate + entrypoint warm-up | Manual deploys in off-hours; `stop_grace_period` for api |
| H12 | No escrow for NTAG 424 master keys, APP_KEY, generated passwords | only in Coolify's DB on the same server | Password manager/vault + checklist step |
| H13 | Dashboard shows API failures as "no data" / "€ 0,00" (cards, transactions, dashboard, team…); settings stuck on skeleton | e.g. `app/(app)/transactions/page.tsx:128` | Shared error state with Retry |
| H14 | Error text on tinted background fails WCAG contrast (4.12:1) in waiter terminal, money/transfer dialogs, login | `bg-destructive/10 text-destructive` | Darker red on tinted backgrounds |
| H15 | Waiter app: signed-out start on a slow network never reaches sign-in (2 s config timeout) | `api_client.dart:32`, `session_controller.dart:220` | 10 s when signed out, or non-blocking config |
| H16 | Waiter app iOS "update required" button does nothing (`APP_STORE_URL` empty) | `config/production.json`, `s15_session.dart:374` | Fill store URLs; `release.sh` fails when empty |
| H17 | Real-device verification never done: NFC hardware matrix, secure-storage upgrade from 1.4.1, iOS build/TestFlight, App/Universal Links | see section 6 | Device test round before launch |

## 5. Medium and Low

**Medium**

| Area | Issue |
|---|---|
| Auth | Password change/reset does not revoke API or waiter device tokens |
| Auth | Account lockout (10 failures) can be triggered by anyone and reveals existing accounts |
| Auth | Reset-password response distinguishes unknown e-mail vs invalid token (enumeration) |
| Auth | Invitation and forgot-password share one token table: a forgot request breaks a pending invitation and gets 72 h validity |
| NFC | Scan-failure limit keyed on IP only: one restaurant's typos block all its terminals (and NAT neighbours); per-terminal limits keyed on client-chosen device id |
| NFC | NTAG 424 SUN MAC input empty (token not covered); chip UID bound on first valid tap; one platform-wide key |
| NFC | Plain NTAG21x tags stay rewritable by default (`lock_nfc_tags_after_write` false) |
| Money | Transfer replay with same key but different amount returns success |
| Money | No correction after a card was replaced; no void/refund of a sale |
| Money | Concurrency guarantees only tested on SQLite (no row locks); no MySQL race test in CI |
| Web | Ctrl/⌘+Enter bypasses the pending lock in ReasonDialog (reverse/replace/block/expire); reverse/replace without idempotency key |
| Web | Guest page says "voucher not found" on any error (503, 429) |
| Web | `<html lang="en">` on German guest and print pages; focus lost after closing dialogs |
| Web | Platform admin without acting restaurant sees misleading restaurant screens (€ 0, "create first card") |
| Web | API validation errors shown as one toast in settings/team/edit-card forms; NFC dialog spins forever on error |
| Web | No confirmation for API-token revoke and team deactivate; waiter terminal tap targets < 44 px; CSP allows `unsafe-inline` |
| Product | Staff UI English-only while the market is DACH (formats already German) — product decision |
| App | Android cold-start NFC tap dropped; uncertain redeem discarded after 15 min background; biometrics cannot be re-enabled; iOS staging/dev share the production bundle id; balance ≥ € 100 000 freezes lookup |
| Ops | SMTP timeout unset (60 s) with synchronous invitation/test mail; no `request_terminate_timeout` |
| Ops | Caddy access logs contain card tokens and invitation/reset links |
| Ops | Log rotation/retention and disk growth (MySQL binlogs 30 days) unmanaged; RPO 24 h, restore never rehearsed, dumps unencrypted |
| Ops | Audit log immutable only in the app; actor reference nulled when users are deleted; no retention; no audit export |
| Ops | Migration lock can block 1 h after a killed container; Redis without `maxmemory`; scheduler `withoutOverlapping` 24 h; SPF/DKIM/DMARC undocumented |
| GDPR | No retention for IPs/user agents/notification recipients; staff PII in immutable audit values; anonymization misses notification errors |

**Low** — 419 error format; `Cache-Control: no-store` never applied; owner can probe registered e-mails; owner can
silently take over a co-owner; unlimited device registration; next/postcss advisory (build-time); reversal can
exceed max balance; expiry job does not re-check the date under lock; "mark as written" silently drops a verified
chip binding; floating base images; JIT buffer; HSTS header mismatch; leading-wildcard card search; guest page ships
the waiter terminal bundle (193 kB); station log re-renders every second; iOS NFC sheet may hang 60 s; start-up
error misclassified as storage; stale version comment in `release.sh`.

## 6. Cannot be verified without devices or production access (launch requirements)

1. NFC read/write on the device matrix (Pixel, Samsung; iPhone XS+): NTAG213/215/216 and NTAG 424 DNA, reader mode,
   background tag, cold start.
2. Upgrade of an installed 1.4.1 (biometric-mode storage) to 1.4.2 on Android and iOS.
3. First iOS build, TestFlight, App Store review; Play internal track with R8 release build.
4. `assetlinks.json` with the Play App Signing fingerprint; `apple-app-site-association` with the Team ID.
5. Production `CARD_BASE_URL` equals the domain printed on cards.
6. TalkBack/VoiceOver walkthrough of redeem, 200 % text on a small phone.
7. Restore rehearsal from an off-site backup with measured RTO.
8. The C2 race under real MySQL latency (load test).

## 7. Execution plan (ordered by business impact)

**Stage 0 — before any real guest money (2–3 days)**
1. C4 server: resize to ≥ 4 GB, add swap, reduce `pm.max_children`, memory limits. *(ops, hours)*
2. C5 + H9 + H12: off-site encrypted backups with freshness alert; prune-after-success; escrow of keys and secrets. *(ops, 1 day)*
3. C1 + H2: no default expiry, reinstate correction, expiry only when due. *(backend, 1 day; legal sign-off)*
4. C2 + C3: idempotency re-check under lock; uncertain-state handling in app and web terminal; last-attempt outcome in the scan response. *(backend + app + web, 2 days)*
5. H1: transfer amount validation. *(web, hour)*

**Stage 1 — first week**
6. H7 + H8: error tracking (API, web, app), uptime check, worker heartbeat, failed-job alerts.
7. H10 + H11: pre-migration dump, fail-the-deploy migrations, deploy windows.
8. H4 + H5: device-bound remember-me and session revocation; admin token policy.
9. H13 + H14: error states with retry; contrast.
10. H15 + H16: app start-up timeout; store URLs; release guard.
11. H3: NFC policy decision ("chip required" for 424 cards) and scan nonce.

**Stage 2 — second week (gate: all Critical and High closed)**
12. H6: MFA for platform admin and owners, step-up for sensitive actions.
13. H17: device test round (section 6), then Play internal track + TestFlight.
14. Security Mediums with low effort: token revocation on password change, separate invitation token table, lockout by IP/device, access-log redaction, reset enumeration.

**Stage 3 — during the pilot**
15. Remaining Medium items (money corrections, MySQL concurrency CI, NFC 424 MAC coverage and provisioning UID, tag locking default, web UX items, GDPR retention, audit log hardening, ops hygiene).
16. Product decision: German staff UI.
17. Low items as backlog.

**Launch gate:** production-ready only when C1–C5 and H1–H17 are closed, the section-6 checks are done, and the
four e2e journeys plus the backend suite pass against the release candidate. Expected overall score after
stages 0–2: ~85–88 %.
