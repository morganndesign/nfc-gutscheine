# GiftCard Pro: production and investor-grade audit

**Date:** 28 September 2026
**Scope:** the whole system as committed at `3527773`:

- Laravel 12 API, Next.js 15 dashboard and admin, Flutter waiter app 1.4.x, NFC writer;
- `docker-compose.coolify.yml`, backups and CI.

**Assumption:** real restaurants in Austria will sell and redeem real prepaid vouchers from the first day.

**Rule of this report:** every finding below was **reproduced**, either by a script or test run against the real stack or by an exact code path with a failing test. Anything I could not reproduce is listed as *refuted* or *not proven* and is not counted.

The previous report (`2026-09-28-production-readiness-audit.md`) was partly a code-reading checklist. Where its claims were measured this time, they were confirmed or corrected; section 9 lists the corrections.

---

## 1. Summary for decision makers

**What is solid, measured under attack and failure:**

| Area | Result |
|---|---|
| Money cannot be created or lost by concurrency | 24–30 parallel terminals, overdraw attempts, crossed transfers, double reversals: **0 ledger violations** across 1 512 cards and 9 359 transactions |
| MySQL crash safety | `kill -9` of mysqld during 30 terminals × redeem: InnoDB recovered, **0 violations, 0 double bookings** |
| Tenant isolation | Tenant A → tenant B, 33 routes: every one answers 404 |
| NTAG 424 replay protection | Replayed SUN messages are refused, including the same counter and a lower counter |
| Backup and restore | The dump and restore reproduce the database exactly: same counts, same balance sum, invariant clean |
| Capacity | 2 vCPU box: about 12–14 redemptions/s at saturation (≈ 50 000/hour). 60 terminals at once, p95 3.0 s, no errors. Whole runtime stack peaks at **0.9 GB RAM** |

The ledger core (row locks, idempotency keys, balance = Σ transactions) is well engineered. It is the asset.

**What stops a paid launch today:** 11 blockers (section 8), in four groups.

1. **Legal: voucher money forfeited unlawfully.**
   - Every card expires after 36 months by default.
   - The nightly job then **writes the remaining balance off irreversibly**.
   - Austrian case law makes this clause unenforceable for paid vouchers: the claim runs 30 years, and a validity of 3 years or less in standard terms is inadmissible.
   - A manager can also expire any card at any time, irreversibly.
2. **Guests can be charged twice.**
   - Four proven paths lead from a network hiccup to "declined / nothing was booked" on the waiter's screen while the voucher *was* debited. Sections 4.1 and 5.2 give the details.
   - The waiter then takes cash, or taps again with a new key.
   - The MySQL crash test showed that "error, but booked" happens in real outages.
3. **Access control can't be recovered after a compromise.**
   - An API token created by a platform admin has **cross-tenant, unrevocable platform rights**.
   - Password reset doesn't sign out tokens.
   - A revoked device regains access with the "remember me" cookie.
   - NTAG 424 anti-cloning is bypassed by sending the card's token as `method: "qr"`.
4. **Operations.**
   - Backups live only on the same server.
   - After 15 days of silent backup failures, the backup loop **deletes the last good dump**.
   - One slow SMTP server blocks every tenant's till for about 60 s.
   - 10 failed scans lock out every restaurant behind the same IP.

**Effort to clear the blockers:** about 70 engineering hours (≈ 2 weeks for one senior engineer, including tests), plus 1 day of ops work. None needs a redesign.

---

## 2. Scores

The weights reflect "real money in restaurants": integrity and security count more than polish.

| Area | Score | Basis |
|---|---|---|
| **Launch readiness** | **52 %** | 11 blockers open; all small and well understood |
| Backend | 74 % | Ledger and tenancy proven sound. Idempotency re-check, expiry/write-off, reversal limit and transfer replay open |
| Platform Admin | 66 % | Complete feature set. The admin-created API token (S2) is a critical escalation |
| Restaurant Dashboard | 72 % | Works and is accessible. Transfer "unparseable amount = full balance", key rotation on conflict, remember-me session survives device revocation |
| Waiter App | 55 % | Redeem core sound. Ambiguous-result handling (M1, M2, M6) can double-charge; no crash reporting; iOS update button dead |
| NFC Writer | 68 % | Write→verify→bind and SUN replay proven sound. Chip verification bypassable (S8); no NTAG 424 keys enforced in the compose defaults |
| Security | 58 % | Isolation, CSRF, mass assignment and SSRF good. Token lifecycle (S1, S2, S3), NFC bypass, IP lockout cross-tenant |
| DevOps | 60 % | Deploys and recovers cleanly, restore proven. No off-site backup, prune-on-failure, fake worker healthchecks, 15 s outage per deploy, a failed migration wedges deploys |
| Mobile (overall app engineering) | 57 % | 626/626 tests green. Error handling at app level, persistence of pending operations, environment separation on iOS |
| **Overall** | **63 %** | |

After the section 8 blockers are closed, the expected scores are about Launch readiness 85 %, Security 80 %, DevOps 78 %, Waiter App 75 % and Overall 80 %.

---

## 3. Method and test rig

| Rig | What it is |
|---|---|
| Production-like stack | `docker-compose.coolify.yml` unchanged, plus `evidence/2026-09-28/infra/override.yml`. It adds prebuilt images from the current code, a published gateway port and Mailpit. Coolify-style `SERVICE_*` variables. php-fpm image, Caddy gateway, MySQL 8.4 (READ-COMMITTED, 512 MB buffer pool), Redis 7.4 (AOF, noeviction), worker, scheduler, backup |
| Payments rig | Same code on MySQL 8.4 with 24 php worker processes |
| Security rig | Session (SPA) and token clients; PHPUnit probes |
| Mobile | Flutter 3.47.5: the full 626-test suite plus 44 audit tests that reproduce each finding |
| Load generator | Python threads on the same 2-vCPU host. The capacity figures are therefore **conservative** |

**Evidence.** Everything is committed under `docs/reports/evidence/2026-09-28/`: every script, every log, the fix diff for the payment findings and the Dart and PHP probes. Re-run the payment probes with `payments/run_all.sh`; each infra probe is a single script.

**Estimates:**

- *Probability* is per restaurant per year of normal operation unless stated otherwise.
- *Financial impact* assumes a typical restaurant selling about €30 000 of vouchers a year: average card €50, about 30 redemptions a day, 10–15 % breakage (never fully redeemed).
- *Effort* is senior-engineer hours including tests.
- These are estimates, not measurements.

---

## 4. Payment integrity

### 4.1 P2: a same-key request in flight during the lock is answered "declined" although the first one booked. **Blocker**

**Reproduce.** Send two identical redeem requests with the same `Idempotency-Key`, the second while the first holds the card lock (a client retry after a slow response). Script: `payments/p2_same_key_inflight.py`, log `p2.log`.

**Evidence:**

- The first request gets 201.
- The second request **does not replay**. It gets `422 CARD_NOT_REDEEMABLE` (full-balance redeem) or `422 INSUFFICIENT_BALANCE` (large redeem).
- The same happens with transfer (`INSUFFICIENT_BALANCE`) and with reload to the maximum (`BALANCE_LIMIT_EXCEEDED`), per `p2b.log`.

**Root cause.** `GiftCardService::idempotent()` (`app/Services/GiftCards/GiftCardService.php:818`) looks the key up only *before* `lockForUpdate()`. The second request waits on the lock and then validates against the already-debited balance.

**Why it matters:**

- The ledger is correct: exactly one booking.
- But the device that retried is told "declined". The app then shows "Nothing was booked." (M1).
- The waiter takes cash or another payment.
- The **guest is charged twice**: voucher debited plus cash.

**Assessment:**

| | |
|---|---|
| Probability | Needs a client retry within the lock window (≈ 50–300 ms). The waiter app retries on timeouts, so it occurs on bad Wi-Fi. Estimate: 1–5 times per restaurant per year |
| Financial | Average €40 per event, refunded manually once noticed |
| Customer | A guest paid twice. Trust damage; staff can't explain it |
| Legal | Unjust enrichment (§ 1431 ABGB): repayment claim. Low monetary, high reputational |
| Severity | **High** |

**Fix.** Re-run `findByKey` after taking the lock(s) and replay if the key now exists. For transfer, do this after both locks. Needs READ-COMMITTED, which the compose file already sets. The diff is in `payments/fix.diff`. It was verified: `p2_fixed.log` and `p2b_fixed.log` replay correctly, and the full suite is green (`fix_full_suite.log`).

**Effort:** 3 h.

### 4.2 P6: default expiry of 36 months, then the balance is written off irreversibly. **Blocker (legal)**

**Reproduce.** Script `payments/p6_p7_expiry.py`, log `p6_p7.log`:

1. Issue a card; `default_validity_months` is 36 (`database/migrations/2026_01_01_000001_create_platform_tables.php:42`).
2. Move time past the expiry and run `giftcards:expire`.
3. The balance is booked out as `expiration`, and the card is `expired`.
4. Then try every recovery path: reactivate, reload, reverse the expiration transaction, unblock. **All are refused.**
5. Blocked cards are also written off by the job.

**Legal basis, verified from primary and secondary sources:**

- For paid vouchers, the claim runs **30 years** (§ 1478 ABGB).
- OGH **7 Ob 22/12d** (28 June 2012) held a **2-year** validity clause in consumer terms void under § 879(3) ABGB: "the shorter the period, the weightier the justification must be".
- WKO guidance states that limiting paid vouchers to **3 years or less** in standard terms is not admissible.
- A 1-year validity followed by a 3-year window for exchange or refund was accepted.
- A void clause falls away entirely, so the 30-year rule applies.
- Sources: [OGH 7 Ob 22/12d (full text)](https://verbraucherrecht.at/system/files/typo3/OGH_28.06.2012_7_Ob_22_12d.pdf), [VKI summary](https://verbraucherrecht.at/ogh-verkuerzung-der-gueltigkeitsfrist-von-gutscheinen-auf-zwei-jahre-ist-unwirksam/2674), [WKO: Gutscheine – Befristung](https://www.wko.at/vertragsrecht/gutscheine-befristung), [AK sample letter "abgelaufener Gutschein"](https://www.arbeiterkammer.at/service/musterbriefe/Konsumentenschutz/Kauf/Abgelaufener_Gutschein.html).
- *This is not legal advice. Have an Austrian lawyer confirm the final wording.*

**Assessment:**

| | |
|---|---|
| Probability | Certain: every card sold with the defaults, from month 37 onward |
| Financial | Breakage of 10–15 % of voucher sales per restaurant (≈ €3 000–4 500 a year on €30 k sales) is booked out unlawfully. Every guest who complains must be repaid. Warning letters from AK or VKI, or a collective action (Verbandsklage), against restaurants **and** the platform whose terms and defaults produce this |
| Customer | A guest with a €80 card is told "expired, balance €0". The system can't even undo it |
| Legal | **High.** Unfair-terms and consumer-protection exposure (§ 879(3) ABGB, § 6 KSchG); UWG warning letters from competitors or associations |
| Severity | **Critical** |

**Fix:**

1. Make "no expiry" the default for paid vouchers. If a restaurant sets a validity, enforce at least 3 years plus a redemption or refund window, and show a warning.
2. At expiry, **don't write off**. Mark the card `expired`, keep the balance, and allow "reinstate", which creates a ledger type `reinstatement` with an audit entry.
3. Skip blocked cards in `giftcards:expire`.
4. Offer a reversible write-off as an explicit, audited action (for vouchers older than 30 years).

**Effort:** 6–8 h including the migration of existing settings and tests.

### 4.3 P7: a manager can expire any card at any time, irreversibly. **Blocker**

**Reproduce.** In `p6_p7.log`, a manager calls `POST /cards/{id}/expire` on an €80 card valid until 2029. The balance is written off, and nothing can undo it (see 4.2).

**Why it matters.** Any manager, whether a disgruntled one or someone using a stolen session, can destroy guests' money. A manager can also expire the card and then pay the guest a "refund" in cash. The balance disappears from the books either way.

**Assessment:** probability low per restaurant, but the impact per event is the full card value. Severity **High**.

**Fix.** Solved by the 4.2 fix (expiry keeps the balance and reinstatement exists). In addition, restrict `cards.expire` to the owner and require a reason.

**Effort:** 2 h on top of 4.2.

### 4.4 P8a: reversing a redemption can push the balance above `max_card_balance`

**Reproduce.** `payments/p5_p8_reverse.py`, log `p5_p8.log`: redeem, reload up to the maximum, then reverse the redemption. The balance ends at 250 000 against a limit of 200 000.

**Assessment:**

- Circumvents the stored-value cap the restaurant configured. The cap can matter for anti-money-laundering (AML) or e-money exemption arguments.
- Probability low (needs an operator); financial impact small.
- Severity **Medium**.

**Fix.** Check the limit in the reversal path (in `fix.diff`, verified in `p8_fixed.log`).

**Effort:** 1 h.

### 4.5 P3: a transfer replay with the same key but a different amount returns "replayed 200"

**Reproduce.** `payments/p3_key_reuse.py`, log `p3.log`. Redeem correctly answers 409 for the same situation; transfer doesn't.

**Assessment.** The client is told its (different) transfer succeeded although the original amount was moved. Severity **Medium**.

**Fix.** Compare the amount in `replayTransfer` (in `fix.diff`, verified in `p3_fixed.log`).

**Effort:** 1 h.

### 4.6 P9: loose amount parsing

**Reproduce.** `p9.log` shows the amount values that the API accepts:

| Sent `amount` | Booked as |
|---|---|
| `10.0` | 10 cents |
| `true` | 1 cent |
| `1e2` | 100 cents |
| `" 100"` | 100 cents |

**Assessment.** No known client sends these, but a third-party integration that sends euros as a float would book 1/100 of the amount. Severity **Low**.

**Fix.** Validate with `integer` plus `strict`, and reject floats and strings.

**Effort:** 1 h.

### 4.7 Dashboard transfer: an unparseable amount means the full balance

**Location.** `dashboard/src/components/cards/transfer-dialog.tsx:33`: if the amount field can't be parsed, the request transfers the **full balance**.

**Assessment:**

- Proven from code, including the reproduction input "12,5,0".
- Reversible by a manager, but money moves to the wrong card.
- Severity **Medium**.

**Fix.** Block submit unless the amount parses; make "full balance" an explicit checkbox.

**Effort:** 1 h.

### 4.8 Proven sound (not issues)

| Probe | Result |
|---|---|
| P1: 20 parallel redeems on one card | No overdraw; the velocity limit holds under the lock |
| P4: crossed transfers A→B and B→A in parallel | No deadlock surfaced as an error; money conserved |
| P5: parallel double reversal | Exactly one reversal |
| P8b | Refuted |
| Ledger invariant (balance = Σ, row arithmetic, chain, last row = card, no negative balance, cap) | **0 violations** after every probe, the crash tests and the load test (latest: 1 512 cards / 9 359 transactions) |

---
## 5. Security

All probes: `evidence/2026-09-28/security/` (PHPUnit probes `S4S6AuthTest`, `S6AgedTest`, `S8NfcBypassTest`, tenant sweep `s9_sweep.py`).

### 5.1 S2 — API token created by a platform administrator is cross-tenant and cannot be revoked. **Blocker**
**Reproduce:** platform admin → `POST /api/v1/api-tokens` (`ApiTokenService::create`, `app/Services/ApiTokens/ApiTokenService.php:26`). The token is stored with `restaurant_id = NULL` (the admin's) and the admin's `platform.*` abilities. With it: list all restaurants, and act inside **any** tenant (tenant header) including card operations; the token list and revoke endpoints are tenant-scoped, so the token never appears anywhere and `revoke` cannot reach it. Lifetime 365 days.
**Why it matters:** a bearer credential with god-mode over every restaurant's money, living a year, with no kill switch short of SQL. Leaks happen (scripts, CI, laptops).
Probability low · Financial: unbounded (issue/redeem/transfer in any tenant) · Legal: GDPR Art. 32 (no ability to revoke access) · **Severity: High** (would be Critical if tokens were used; today only an admin can mint one).
**Fix:** forbid API tokens for platform admins (or restrict to `platform.*` read abilities, never tenant operations), list and revoke them in the admin UI, audit every use. **Effort 4 h.**

### 5.2 S8 — NTAG 424 / bound-UID chip verification bypassed with `method: "qr"` or `"api"`. **Blocker**
**Reproduce:** `S8NfcBypassTest.php`. `CardScanService::resolve` verifies the chip only for `nfc` and `link` (`app/Services/GiftCards/CardScanService.php:73`). Sending the card's public token (readable from the NDEF URL by any phone, and part of the guest's balance link `/c/<token>`) as `method: "qr"` returns the card, and redeem follows. SUN replay protection itself is sound — it is simply not required.
**Why it matters:** the product's anti-cloning promise for secure cards does not hold: anyone who once read a guest's card (1–2 cm, any NFC phone) or saw the balance link can spend the balance from a screenshot QR. Redeem is also not bound to a successful scan (A04): with a card id, `POST /cards/{id}/redeem` works directly.
Probability: low today, rises with value on cards · Financial: card balances (€50–200 per event) · Customer: guest loses money, restaurant pays twice · **Severity: High.**
**Fix:** per card, store which scan methods are allowed (NTAG 424 / bound UID → `nfc`/`link` only unless the restaurant explicitly printed a QR); refuse others with an audited `SCAN_METHOD_NOT_ALLOWED`; issue a short-lived scan ticket that redeem must present. **Effort 4 h** (+2 h for the scan ticket).

### 5.3 S1 — a revoked device regains access with the "remember me" cookie. **Blocker**
**Reproduce:** log in on the dashboard with "remember me" (the default — the checkbox is pre-ticked), revoke that device, delete the session cookie, keep `remember_web_*`, send a new `X-Device-Id` → access is restored as a new device (`TrackDevice` pins only the *session*; `AuthController.php:36` issues the recaller). The sub-claim that existing sessions survive revocation is **refuted** (they are blocked).
**Why it matters:** "lost/stolen tablet → revoke device" is the documented response; it does not work for owners/managers, whose sessions can issue cards (create value) and expire cards (4.3).
**Severity: High.** **Fix:** on device revocation rotate the user's `remember_token`; bind recaller logins to the device; default "remember me" off on shared devices. **Effort 5 h.**

### 5.4 S3 — password reset does not revoke device tokens or API tokens. **Blocker**
**Reproduce:** `S4S6AuthTest.php`: reset the password → the old waiter-app device token and API tokens keep working (`PasswordController::reset` rotates only `remember_token`).
**Why it matters:** "I think my account is compromised → reset password" leaves the attacker in. **Severity: High.** **Fix:** on reset/change revoke all personal access tokens and device tokens of the user (except the current one on change), log it. **Effort 3 h.**

### 5.5 S7 — scan-failure lockout per IP blocks every user and every tenant on that IP. **Blocker (operational)**
**Reproduce:** 10 failed scans from one IP (e.g. worn cards, other restaurants' cards) → `429` for *all* users of that IP, including tenant B scanning its **own** valid card (`throttleKeys`, `CardScanService.php:227`).
**Why it matters:** a restaurant's terminals share one public IP (router NAT); so do a shopping centre's or a franchise's. Ten bad reads during dinner service stop the whole restaurant's redemptions for the decay period; a malicious guest can trigger it deliberately.
Probability: medium (weekly in busy venues) · Financial: lost sales / guests sent away · **Severity: High (availability).**
**Fix:** key the lockout by user + device (and restaurant), keep a much higher per-IP ceiling only for unauthenticated/public lookups. **Effort 3 h.**

### 5.6 Medium / Low
| # | Finding (proven) | Severity | Fix · effort |
|---|---|---|---|
| S4 | Locked account: correct password gives 423, wrong gives 422 → confirms the password during lockout; account enumeration | Medium | Same response for both while locked · 2 h |
| S6 | `forgot-password` for an invited (not yet activated) user overwrites the pending invitation after the 60 s throttle; an attacker who knows the address can keep invitations invalid | Medium | Separate brokers must not share the token row; ignore reset for never-activated users · 2 h |
| S5 | Reset response timing/wording reveals existing accounts | Low | Constant response + queued mail · 1 h |
| L1 | Password-reset URLs incl. the user's e-mail, and card public tokens (`/c/<token>`, a bearer credential per S8) are written to the gateway access log (`uri` field, verified in `gcpaudit-gateway-1` logs); Docker's default json-file driver keeps them without rotation | Medium (GDPR Art. 5(1)(e), 32) | Caddy `log` filter redacting query strings and `/c/*`; `logging: max-size/max-file` in compose · 1 h |
| F3b | `forgot-password` answers **500** when SMTP fails (invitations handle the same failure gracefully) | Low | Catch transport errors, still answer 200, log · 0.5 h |
| D1 | `npm audit`: 1 high (postcss via next, build-time only) | Low | Update next · 0.5 h |
| D2 | `.env.production.example` lacks `SESSION_SECURE_COOKIE=true` (compose sets it — no production impact) | Info | Doc line |

### 5.7 Proven sound
Tenant isolation (33 tenant routes × foreign ids → 404, incl. transactions, customers, exports); mass assignment (refuted); CSRF on the SPA; CSV-injection in exports (escaped); no SSRF surface; rate limits as designed (login 5/min per e-mail+IP and 30/min per IP, public card 20/min, API 240/min per user, scan 90/min per terminal); SUN counter replay; audit logging of security events; Customer GDPR anonymisation (also scrubs the notification log).

---

## 6. Resilience, DevOps, performance — measured on the production-like stack

### 6.1 Failure injection
| Probe | Result | Verdict |
|---|---|---|
| **F1a** `docker restart mysql` during 30 terminals × redeem (`infra/f1_restart.log`) | 575 × HTTP 500 over 8.5 s, fast-fail (max 1.7 s), recovery automatic; **0 of 575 errors were booked**, 0 duplicate keys; same-key retries after recovery booked exactly once | ✅ sound |
| **F1b** `kill -9` mysqld (OOM-like) during load (`infra/f1_kill.log`) | Docker restarted MySQL, InnoDB crash recovery OK; 320 × 500 over 6.3 s; **1 request answered 500 although committed** ("2006 MySQL server has gone away" at commit) — its same-key retry **replayed** correctly; invariant 0 violations | ✅ server sound — **proves the ambiguous-outcome case is real**, so client key handling (M1/M2/M6) decides whether guests are double-charged |
| **F1c** `docker kill` (manual stop) | Docker does **not** restart a manually killed container → MySQL stays down; API still reports `healthy` because its healthcheck only pings php-fpm | ⚠ see D5 |
| **F2** Redis stopped (`infra/f2_redis.log`) | Every authenticated request and `/up` → 500 in ~40 ms (no hang); no booking during outage; worker exits and is restarted; everything recovers without intervention; AOF keeps data | ✅ fail-fast; Redis is a single point of failure (accepted for single-server) |
| **F3** SMTP accepts but never answers (`infra/f3_smtp*.log`) | Staff invitation: **61.5 s** then 201 + logged failure; forgot-password: **60.4 s then 500**; 26 concurrent invitations **occupied all 24 php-fpm workers** — a waiter's redeem in another request waited **58.6 s** | ❌ **blocker F3** |
| **B4** redeploy (api/worker/scheduler recreated) under 10 terminals (`infra/b4_redeploy.log`) | 277 × 502 over **14.8 s**; none booked | ⚠ D6 |

### 6.2 F3 — slow SMTP freezes every restaurant's till. **Blocker**
Cause: `config/mail.php:50` `timeout => null` (PHP default 60 s socket timeout), invitations and password resets sent **synchronously** in the web request, one php-fpm pool (`pm.max_children = 24`) shared by all tenants, no `request_terminate_timeout`. Trigger: a provider outage, a firewall silently dropping port 587 (Hetzner blocks some outbound mail ports on new projects), or — while mail is slow — 24 `forgot-password` calls per minute from 5 IPs (public, 5/min/IP).
Probability: medium (mail incidents are common) · Financial: every tenant cannot redeem for ~1 min per wave · Customer: guests wait / leave · **Severity: High.**
**Fix:** `MAIL_TIMEOUT=10` (`'timeout' => env('MAIL_TIMEOUT', 10)`), send invitations and resets through the queue (`ShouldQueue` notifications; the invitation status already exists in `notification_logs`), `request_terminate_timeout = 30s` in `www.conf`. **Effort 3 h.**

### 6.3 Backups
- **B1 drill (`infra/b1_backup_restore.log`)** — the exact command of the backup service dumped 1 512 cards / 9 359 transactions in 1.5 s (1.6 MB gz); restore into a fresh MySQL 8.4 in 3.8 s; counts, balance sum (842 837.00) and the ledger invariant identical. ✅
- **B2 — a failing backup deletes the last good backups. Blocker.** Reproduced with the verbatim loop body (`infra/b2_backup_failure.sh`): dumps exist but the newest is 15 days old (backups have been failing, e.g. after a root-password change); the next run fails (`Access denied`), logs "Backup FAILED" to stderr, then `find -mtime +14 -delete` removes **all** of them → **0 backups**; the container keeps running, no alert.
- **C5 (confirmed) — no off-site copy.** Dumps live in a Docker volume on the same disk. Disk/server loss, ransomware on the host, or `docker volume prune` = all balances (money owed to guests) gone, and nothing proves who owns what.
- **APP_KEY** is generated into the `laravel-storage` volume, not into the backup. It is not needed to read the ledger (no encrypted columns), but losing it logs everyone out and invalidates signed links; NTAG 424 keys live only in Coolify env.
Combined **severity: Critical** (probability low per year, impact existential). **Fix:** prune only after a successful dump and never below N files; encrypted off-site copy (Hetzner Storage Box / S3 via `rclone` or `restic`) from the backup container; heartbeat to a monitor (healthchecks.io / Uptime Kuma) on success; document key escrow (APP_KEY, NTAG424 keys, SERVICE_PASSWORD_*); monthly restore test. **Effort 8 h + ops.**

### 6.4 Deployment safety
| # | Finding (proven) | Severity | Fix · effort |
|---|---|---|---|
| D3 | **A failed migration wedges production.** Probe `infra/bad_migration.php`: MySQL DDL auto-commits, so a migration failing at step 3 leaves steps 1–2 applied; entrypoint (`set -eu`) exits, `restart: unless-stopped` loops; the next attempt fails with `Table already exists`; **even the corrected migration fails the same way**. api, worker and scheduler all run migrations → full outage until manual SQL. | High | One DDL per migration + `Schema::hasTable/hasColumn` guards; pre-deploy dump; runbook "roll back a failed migration"; CI runs migrations against a copy of production-shaped data · 4 h |
| D4 | Worker and scheduler healthchecks always pass: `pgrep -f 'queue:work'` matches the shell running the check itself (demonstrated: returns its own PID) | Medium | `pgrep -f '^php artisan queue:work'` or a heartbeat file; `queue:monitor` exists but needs a notification route · 1 h |
| D5 | API healthcheck only pings php-fpm, so Coolify shows "healthy" while MySQL is down; no external monitoring configured | Medium | Point an uptime monitor at `/up` (checks DB + cache), alert by e-mail/SMS · 1 h ops |
| D6 | Every deploy = ~15 s of 502 for all tenants (Coolify recreates containers; php-fpm has no graceful `SIGQUIT` stop) | Low | Deploy outside service hours (document); `STOPSIGNAL SIGQUIT` · 0.5 h |

### 6.5 Load and memory
Stack on 2 vCPU / 8 GB (generator on the same host), QR scan + redeem per terminal, 0.5 s think time, plus 4 dashboard users (`infra/l1_load.log`):

| Terminals | Throughput | Redeem p50 / p95 / p99 | Scan p95 | Dashboard stats p95 | Errors |
|---|---|---|---|---|---|
| 10 | 23.9 req/s, 10.2 redeems/s | 155 / 592 / 792 ms | 654 ms | 1.29 s | 0 |
| 30 | 29.7 req/s, 13.7 redeems/s | 803 / 1 553 / 1 828 ms | 1.39 s | 2.16 s | 0 |
| 60 | 25.3 req/s, 12.0 redeems/s | 2 195 / 3 000 / 3 442 ms | 2.92 s | 3.70 s | 0 |

Saturation ≈ 12–14 redemptions/s (CPU-bound) ≈ 45 000/hour — two orders of magnitude above what 100 restaurants need at peak (~5/min each). Invariant clean afterwards.
**Peak memory (docker stats, 2 s sampling):** MySQL 585 MB, api (24 fpm workers) 110 MB, web 53, scheduler 53, worker 33, gateway 27, redis 5 → **≈ 0.9 GB runtime**. Next.js production build measured separately: **≈ 860 MB** peak.
**Consequence for the 2 GB production server:** runtime fits; runtime + Coolify (itself ~0.5–1 GB, not measured here) + a build on the same host (0.9 GB web + composer) exceeds 2 GB with no swap → OOM killer during deploys is likely (not reproduced on the real server). **Fix (ops, 1 h):** 4 GB server or ≥ 2 GB swap; optionally build images in CI.

---

## 7. Waiter app and mobile (Flutter)
Baseline 626/626 tests green; 44 audit tests in `evidence/2026-09-28/mobile/` reproduce each item.

| # | Finding (proven) | Severity | Fix · effort |
|---|---|---|---|
| **M1** | After an ambiguous failure, the retry path treats a 4xx answer as final and shows **"Nothing was booked."** (`redeemNothingBooked`) — but with P2 or a replay race the first attempt *was* booked; after `409 IDEMPOTENCY_CONFLICT` "tap again" creates a **new key** → second booking | **High — blocker** (double charge; F1b shows the ambiguous case happens) | Never say "nothing booked" after an uncertain attempt; on 4xx after an uncertain attempt show "Check the card balance"; re-fetch the card's last transaction before allowing a new attempt · 3 + 2 h |
| **M2** | Cancelling an uncertain redeem and editing the amount issues a new idempotency key without a re-scan → second booking possible | **High — blocker** | Lock card + amount while an attempt is uncertain until resolved or re-scanned · 4 h |
| **M6** | Uncertain attempts are dropped after 16 min; keys are memory-only (a process restart = new key) | **High — blocker** | Persist pending attempts (key, card, amount) in secure storage; resolve on next start · 6–8 h |
| M3 | `/app/config` timeout 2 s (`lib/core/api/api_client.dart:32`) → cold start on slow Wi-Fi fails | Medium | 8 s + retry · 1.5 h |
| M5 | No global error handler / crash reporting (`FlutterError.onError`, `PlatformDispatcher.onError` absent; no reporter dependency) | Medium | Handlers + Sentry/Crashlytics (GDPR: EU region, no PII) · 4–6 h |
| M7 | NFC tag that launched the app from cold start is dropped (Android) | Medium | Read the launch intent after bootstrap · 2–3 h |
| M4 | iOS "Update" button does nothing | Medium | App Store URL · 0.5 h |
| M9 | Biometric unlock cannot be re-enabled once turned off | Low | Settings toggle · 1 h |
| M8 | Spinner hangs if partial redemption is off and amount ≠ balance (Back recovers) | Low | Show the error · 1–2 h |
| M10 | One iOS bundle id for all environments (Android has suffixes) → dev/staging builds overwrite production on testers' phones | Medium (release process) | Per-configuration bundle ids · 2–3 h |
| M11 | Card-link parsing — **refuted** (holds) | — | — |
| M12 | Redeem happy path, key reuse on 5xx/timeouts — **sound** | — | — |

---

## 8. Launch blockers — must be done before the first paying restaurant

| # | Blocker | Why it blocks | Effort |
|---|---|---|---|
| 1 | **P6 + P7** — no silent forfeiture: default no expiry (or ≥ 3 years + refund window), expiry keeps the balance, reinstatement ledger type, blocked cards skipped, expire = owner-only with reason | Unlawful forfeiture of guest money from month 37; irreversible manager action | 8–10 h |
| 2 | **P2** — idempotency re-check after the lock (redeem, reload, transfer) + **P3** amount check in transfer replay | "Declined" shown for a booked payment → double charge | 4 h |
| 3 | **M1 + M2 + M6** — waiter app never claims "nothing booked" after an uncertain attempt; keeps and persists the key until resolved; locks card + amount | Double charge on every network hiccup that hits the commit | 15–17 h |
| 4 | **S2** — no tenant-capable, unrevocable platform-admin API tokens | Unrevocable god-mode credential | 4 h |
| 5 | **S1 + S3** — device revocation and password reset really lock an attacker out (rotate recaller, revoke tokens) | Compromise cannot be contained | 8 h |
| 6 | **S8** — chip verification cannot be bypassed via `qr`/`api` for secure/bound cards | Cloned/copied cards spend guests' balances | 4–6 h |
| 7 | **S7** — scan lockout per user+device, not per IP across tenants | A few bad reads stop a restaurant (or a food court) at dinner | 3 h |
| 8 | **F3** — mail timeout 10 s, invitations/resets queued, `request_terminate_timeout` | Slow SMTP freezes every tenant's redemptions | 3 h |
| 9 | **B2 + C5** — prune only after success, encrypted off-site backup, success heartbeat + alert, key escrow, restore runbook tested | Silent loss of the only record of what guests are owed | 8 h + ops |
| 10 | **Server sizing** — 4 GB or swap on the production host; uptime monitor on `/up` (D5) | OOM during deploy kills MySQL; outages go unnoticed | 1–2 h ops |
| 11 | **Legal texts** — terms for restaurants and voucher conditions (validity, refund, data processing agreement Art. 28 GDPR between platform and restaurant, privacy notice for guests) reviewed by an Austrian lawyer | The platform processes guest data on behalf of restaurants and shapes their voucher terms | external |

**Total engineering: ≈ 62–71 h** (+ ops and legal). Diffs for #2 already exist and are verified (`payments/fix.diff`).

**Strongly recommended in the first 30 days (not blockers):** D3 migration safety + runbook, D4 real worker healthchecks, P8a, 4.7 transfer dialog, M3, M5 crash reporting, M7, M10, S4, S6, L1 log redaction/rotation, P9, D6 deploy window. ≈ 30 h.

---

## 9. Corrections to earlier statements and refuted hypotheses
| Earlier claim / hypothesis | Measured result |
|---|---|
| Previous audit C4: "3.5 GB+ under load" (fpm children × memory_limit) | **Refuted as stated**: 60 terminals → api 110 MB, whole stack 0.9 GB. The real risk is build + Coolify + runtime on 2 GB without swap (blocker #10) |
| MySQL restart/crash corrupts or double-books | **Refuted**: 0 violations, 0 duplicates in both drills |
| Redis outage causes hanging requests or lost bookings | **Refuted**: fail-fast 500, nothing booked, automatic recovery |
| Concurrent redeems can overdraw | **Refuted** (P1) |
| Tenant data reachable across restaurants | **Refuted** (33 routes) |
| Existing sessions survive device revocation (S1 part) | **Refuted**; only the remember-me path works |
| P8b, M11, mass assignment, SSRF | **Refuted** |

## 10. Reproduce
```
# production-like stack (see evidence/2026-09-28/infra/override.yml for the sandbox overrides)
docker compose -p gcpaudit --env-file stack.env -f docker-compose.coolify.yml -f override.yml up -d
python3 evidence/2026-09-28/infra/f1_mysql_restart.py restart|kill
python3 evidence/2026-09-28/infra/f2_redis_down.py
python3 evidence/2026-09-28/infra/f3_smtp_tarpit.py          # needs the tarpit service + MAIL_HOST=tarpit
python3 evidence/2026-09-28/infra/l1_load.py 10,30,60 0.5
bash    evidence/2026-09-28/infra/b1_backup_restore.sh
bash    evidence/2026-09-28/infra/b2_backup_failure.sh
bash    evidence/2026-09-28/payments/run_all.sh
```
