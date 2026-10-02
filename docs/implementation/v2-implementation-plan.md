# GiftCard Pro v2: implementation plan

| | |
|---|---|
| **Date** | 29 September 2026 (ADR-002 version) |
| **Baseline** | `docs/architecture/giftcard-pro-v2-architecture.md`, **frozen v2.2** (ADR-000, ADR-001, ADR-002) |
| **Starting point** | No production data, no customers. The platform is built in its final form from day one: no migration, compatibility layers, feature flags for old behaviour, legacy modes or transition phases. Code that does not belong to the final platform is deleted. |
| **Priorities** | Security, correctness and maintainability over speed. There is no launch date. The UI/UX polish and the commercial launch follow the complete foundation. |
| **Change rule** | This plan implements the architecture. If a significantly better architecture, security model or workflow appears during implementation, it is proposed with its reasons **before** it is built, and then recorded as an ADR (architecture §20). |

---

## 1. Platforms

- **Android and iPhone are both production platforms**, with full feature parity for everything restaurants and guests use: waiters, managers and owners can do the same on both.
- A customer-facing feature is done only when it passes the hardware matrix (§6.3) **on both platforms**.
- The only Android-only tool is the **internal card-personalisation station**, used by GiftCard Pro staff before cards are shipped.
- Android remains the fastest platform for day-to-day NFC debugging. iOS builds run in CI from Phase 0 on (P0-12), so parity problems appear early, not at the end.

---

## 2. Working rules

**Definition of done** (every story):
1. Code, unit and feature tests. For every security rule, an **abuse test** that tries the forbidden path and must be refused (`tests/Feature/Abuse/`).
2. Audit events for every privileged action; no secret, token or UID in logs.
3. API and error codes documented (`docs/API.md`); owner or staff documentation where a workflow changes.
4. Schema changes are forward migrations that build the final schema. There are no compatibility columns and no data backfills (there is no data).
5. Reviewed by a second person. Crypto code is additionally checked against NXP test vectors and listed for the external cryptographic review.
6. App features: Android and iPhone both pass.

**Environments:**

| Environment | Keys | Purpose |
|---|---|---|
| Local | Test keys (NXP application-note values) | Development, vectors |
| Staging | Separate Google Cloud project and HSM key ring; staging key set | Integration, lab cards, hardware tests, penetration test |
| Production | Production key ring after the key ceremony | Pilot and launch |

Lab cards personalised with the staging key set can never work in production.

---

## 3. Phase 0: security foundation

**Goal.** Build the final core of vouchers, money and proof of presence, and delete everything that does not belong to the final platform. After Phase 0:
- no path exists that spends without cryptographic proof;
- financial history is immutable;
- every known security finding from the audit is closed.

**Effort:** 26–35 engineer-days.

### 3.1 Deleted (not hidden)

| Removed | Where **[Code, commit `0493784`]** |
|---|---|
| NTAG213/215/216 support and every writer or programming flow | Backend `NfcProgrammingService`, the four NFC requests, `NfcWriteAttempt` + resource + enums, the `nfc_write_attempts` table, the NFC routes (`routes/api.php:88–97`); dashboard `lib/nfc-programming.ts`, `nfc-writer.tsx`, `nfc-program-steps.tsx`, `nfc-attempts.tsx`, `nfc-error.tsx`, `use-nfc-programmer.ts`, `cards/program/page.tsx`, `e2e/nfc-programming.mjs`; app `card_programmer.dart`, `tag_writer.dart`, writer paths in `WaiterNfc.kt`, S20 programming |
| NFC state on the voucher and binding at scan time | `gift_cards.nfc_*` columns; `CardScanService.php:139` |
| `public_token` as a bearer credential; the `/c/{token}` page; the QR payload endpoint | `gift_cards.public_token`, `PublicCardController`, `dashboard/src/app/c/[token]`, `routes/api.php:97` |
| `POST /scan` and every lookup that led to spending (QR, link, manual, API methods) | `CardScanService`, `ScanCardRequest`, `routes/api.php:69` |
| Redemption by typed number | App `s11_manual_entry.dart`, `card_number_field.dart`; dashboard terminal manual field |
| Transfers between vouchers; replace-by-transfer | `routes/api.php:81, 87`, `GiftCardService.php:278–431`, `transfer-dialog.tsx` |
| Card number on printouts | `dashboard/src/app/print/cards/[id]/page.tsx` (replaced by the printable voucher sheet, P0-03) |
| `replaced_by_id`, `replaces_id` | Voucher columns |

The existing SUN verification (`Ntag424SunVerifier`, `AesCmac`) stays: it is part of the final platform (Phases 3–4). Its keys move to the crypto service in Phase 1.

### 3.2 Built (final code)

| ID | Story | Accepted when |
|---|---|---|
| P0-01 | **Deletions** of §3.1, with a schema migration dropping the removed tables and columns | No reference to NTAG21x, writer, transfer, replace, `/scan` or `public_token` remains (checked in CI with a grep test) |
| P0-02 | **API resources named as in the architecture:** `/vouchers` replaces `/cards` for every endpoint (list, show, update, activate, block, unblock, expire, history), in the backend, dashboard and app. `card_number` is the internal voucher number, shown to staff only. | The dashboard and app work end to end on `/vouchers` |
| P0-03 | **Voucher kind and digital vouchers:** `gift_cards.kind` (`card`, `digital`). `media` table (final shape; type `printable_qr` now, `nfc_card` and `email_voucher` added in their phases). A printable QR carries a 256-bit secret, stored only as a SHA-256 hash, returned once at issue. The dashboard prints the voucher sheet from that response (QR + restaurant branding, **no number**). | A digital voucher can be sold, printed and redeemed; the secret is never stored in clear or logged |
| P0-04 | **Presentments (final model):** `presentments` table and `PresentmentService` with purposes and methods as in architecture §10.1. Methods are implemented by verifier classes behind one interface: `printable_qr` now, `live_auth` in Phase 4, `rotating_qr` and `email_link` in Phase 7. 60 s validity, single use (atomic `verified → consumed`), bound to user, device (null-safe), restaurant and voucher. `POST /presentments` | Abuse tests: expired, reused, other user, other device, other voucher, card number sent as a credential |
| P0-05 | **Redemption:** `POST /vouchers/{voucher}/redemptions {amount, presentment_id}` + `Idempotency-Key` (required). The idempotency key is looked up again **after** the row lock (audit P2). Strict integer amounts (P9). Kind rule: digital vouchers only with QR methods; card vouchers only with `live_auth` (none can exist before Phase 5). | Parallel and retry tests; a retry after a lost response returns the original result |
| P0-06 | **Payments:** `payments` table (`cash`, `card_terminal`, `online_psp`, `bank_transfer`, `complimentary`). Sale, activation and reload require a payment whose amount matches. `complimentary` requires the owner role and a reason; four-eyes for non-owner sellers arrives with authorizations in Phase 5. | No activation or reload without a payment (tests) |
| P0-07 | **Immutable financial history:** `gift_card_transactions` and `audit_logs` append-only (triggers rejecting UPDATE/DELETE). Reversal is a new event; "reversed" is derived from the reversal entry (unique per original), no column is updated. Hash chains per restaurant for both tables; `giftcard:verify-chains` nightly. Reversal respects the balance cap (P8a). | A direct UPDATE/DELETE fails in tests; the verifier detects a tampered row |
| P0-08 | **Expiry without write-off** (audit P6, P7): no default expiry. At expiry the voucher is `expired` and **keeps its balance**; reinstatement is a new event. Manual expiry is owner-only, with a reason. Blocked vouchers are skipped by the job. | Tests for each path |
| P0-09 | **Authentication and session findings:** S1 (device revocation rotates the remember token; the recaller is bound to the device; "remember me" off by default), S2 (no API tokens for platform admins; admin list and revoke), S3 (password reset or change revokes device and API tokens), S4 (uniform locked-account response), S5 (constant reset response), S6 (invitation and reset tokens separated) | The audit's probes (`S4S6AuthTest`, etc.) turned into passing tests |
| P0-10 | **Availability and logging findings:** S7 (lockouts keyed by user + device + restaurant; a higher per-IP ceiling only for public endpoints), F3/F3b (mail always queued, `MAIL_TIMEOUT=10`, reset answers 200 on transport errors), L1 (gateway log redaction, log rotation), D1 (`next` update) | Tests and a configuration review |
| P0-11 | **Waiter app:** redeem by scanning a digital voucher's QR (presentment → redemption). Uncertain outcomes (audit M1, M2, M6) handled with the same idempotency key and a "checking…" state, never "nothing was booked" when the result is unknown. The NFC path is prepared for Phase 4 (no `/scan` calls remain). S20 becomes "Sell digital voucher" (payment method, amount, e-mail, printable). | Flutter tests; Android and iOS builds green |
| P0-12 | **iOS build pipeline:** CI builds, signs and uploads the app to TestFlight (GitHub Actions macOS runner or Codemagic), using the existing Apple Developer account | Every merge to `main` produces a TestFlight build |
| P0-13 | **Abuse suite** covering every removed path and every presentment rule, running in CI | Green |

### 3.3 Order inside Phase 0

1. Deletions and the schema: P0-01 and P0-03.
2. Presentments and redemption: P0-04 and P0-05.
3. Money integrity: P0-06, P0-07, P0-08.
4. Security findings: P0-09, P0-10.
5. API naming and clients: P0-02, P0-11.
6. iOS pipeline and abuse suite: P0-12, P0-13.

The backend is done first, then dashboard and app, so the clients are written once against the final API.

### 3.4 Status

| ID | Status | Commits |
|---|---|---|
| P0-01 | Done. `RemovedPathsTest` fails when a removed concept reappears in the code | `25ebfda` (backend, schema), `a56b202` (dashboard), `2234694` (app) |
| P0-02 | Done | `25ebfda`, `a56b202`, `2234694` |
| P0-03 | Done: `kind`, `media` (`printable_qr`), printable sheet with the value and without the voucher number in the dashboard and the app (value added by ADR-003) | `25ebfda`, `a56b202`, `2234694` |
| P0-04 | Done: `printable_qr` verifier; `live_auth` is an enum case without a verifier; `expires_in` in the response | `25ebfda`, `33506ca` |
| P0-05 | Done, plus `GET /vouchers/{voucher}/redemptions/{idempotencyKey}` for unknown outcomes | `25ebfda`, `33506ca` |
| P0-06 | Done for sale and reload with `cash`, `card_terminal`, `bank_transfer`, `complimentary` (owner, reason) | `25ebfda` |
| P0-07 | Done: ledger, payments and audit log append-only and hash-chained; `giftcard:verify-chains` nightly and in CI | `25ebfda`, `a56b202` (CI) |
| P0-08 | Done | `25ebfda` |
| P0-09 | Done (S1–S6) | `edeb559`, `33506ca` (dashboard) |
| P0-10 | Done: S7, F3/F3b, L1, D1 | `25ebfda` (S7), `edeb559` (F3, L1), `a56b202` (D1) |
| P0-11 | Done: waiter app 2.0.0; app tokens limited by method and path | `2234694`, `33506ca` |
| P0-12 | Pipeline written: unsigned iOS build in `ci.yml` and `testflight.yml`; the upload runs once the App Store Connect secrets are set | not committed yet |
| P0-13 | Done: `backend/tests/Feature/Abuse`, run by CI on SQLite and MySQL | `25ebfda`, `edeb559`, `33506ca` |

---

## 4. Phases 1–10

Effort is for one engineer **[Assessment]**. Dependencies are listed; phases without a dependency between them run in parallel.

### Phase 1: crypto service and Google Cloud HSM (10–14 days) · depends on Phase 0

| ID | Story |
|---|---|
| P1-01 | Crypto service: its own container, mTLS to the API, its own service account, no database, audit log to a separate sink |
| P1-02 | AES-CMAC, AN10922 (32-byte padding, subkey K2), AN12196 SUN session keys, with NXP vectors in CI |
| P1-03 | Google Cloud HSM adapter: imported roots, CMAC composed from raw AES-CBC with caller IV |
| P1-04 | Operations `sun.verify`, `auth.begin` / `auth.finish` (RndA inside, 30 s, single use), `perso.*` (station identity, approved batch); rate limits |
| P1-05 | Key sets and key references (metadata + KCV), ceremony script, staging ceremony |
| P1-06 | `.env` card keys removed; CI check that no `NTAG424_*` variable exists outside local |
| P1-07 | Two instances, health checks, alerting |

### Phase 2: physical card model (8–11 days) · depends on Phase 0

| ID | Story |
|---|---|
| P2-01 | `cards` (id **UUIDv4 via `HasVersion4Uuids`**, never serialised; `card_number` inventory number; uid; chip type; batch; key set; state; SDM counter) with a CHECK constraint on state |
| P2-02 | `card_events` (append-only, hash-chained) and `CardLifecycle` as the only writer of card state (architecture §7.2); a static check forbids other writers |
| P2-03 | `card_batches` (architecture §8.1), the counts view, and the reconciliation check |
| P2-04 | `media` types `nfc_card` and `email_voucher`; `contacts`, `contact_confirmations`, `authorizations` |
| P2-05 | A global serialisation test proves that no API resource exposes a card `id` or UID |

### Phase 3: tap verification, limits and risk events (7–10 days) · depends on Phases 1 and 2

| ID | Story |
|---|---|
| P3-01 | SUN v2 URL `https://t.giftcardpro.at/{k}?e=…&m=…` via the crypto service; RF UID check; counter compare-and-set on `cards.sdm_counter` |
| P3-02 | Guest balance page on the tap domain (SUN-verified, throttled, restaurant can disable) |
| P3-03 | Limit model (architecture §6.3) |
| P3-04 | **Risk event capture:** every money, card, medium, user and device service writes `risk_events` in its own transaction (append-only, hash-chained). This is the foundation of Phase 8. |

### Phase 4: live authentication on Android and iPhone (12–16 days) · depends on Phase 1

| ID | Story |
|---|---|
| P4-01 | Android relay (`IsoDep`): open, the four fixed commands, byte-for-byte forwarding, nothing stored |
| P4-02 | iPhone relay (`NFCTagReaderSession` ISO 14443 → `NFCISO7816Tag.sendCommand`); entitlements and AID list verified in TestFlight |
| P4-03 | `live_auth` verifier: `POST /presentments` + `/complete` with `auth.begin` / `auth.finish` |
| P4-04 | Latency on the device matrix: p95 time the card must stay on the phone < 0.8 s on both platforms, or a documented exception |

### Phase 5: restaurant workflows on both platforms (16–20 days) · depends on Phases 3 and 4

| ID | Story |
|---|---|
| P5-01 | Sell card voucher: payment → amount → optional e-mail → tap an available card → active |
| P5-02 | Add card to an existing voucher (guest `select` + bind; converts a digital voucher, decision 26) |
| P5-03 | Replace card (lost, damaged or unreadable; recovery rules; 72 h cap) |
| P5-04 | Register card at the counter; change of contact (old address confirms or is notified) |
| P5-05 | Receive cards (count + tap; `on_hold` with per-card check-in) and card info |
| P5-06 | Step-up: device-bound biometric key (Keystore / Secure Enclave) or server-verified PIN |
| P5-07 | Authorizations: four-eyes for sales above the threshold, complimentary vouchers by non-owners, recovery approvals, owner resumes |
| P5-08 | Dashboard: vouchers with media and card lifecycle, batches and stock, reports (payments by method, replacements) |

### Phase 6: central personalisation and batches (10–14 days) · depends on P1-04 and P4-01

| ID | Story |
|---|---|
| P6-01 | Station mode (Android, `station_operator` role, enrolled station device only): intake with the originality signature, personalisation, per-card outsider QA |
| P6-02 | Recovery of interrupted personalisation (deterministic keys, step journal) |
| P6-03 | Platform batch administration: create, release (one person), ship, compromise playbook |
| P6-04 | Manufacturer manifest import and sample acceptance (built when the first manufacturer batch is ordered) |

**Scheduling note:** P6-01 starts as soon as P1-04 and P4-01 exist, so lab cards are ready for the P4-03 tests.

### Phase 7: digital vouchers (6–8 days) · depends on Phase 2

| ID | Story |
|---|---|
| P7-01 | E-mail voucher page, device confirmation code, rotating QR (spending, digital vouchers only) |
| P7-02 | Recovery-contact page for card vouchers: balance, receipts, suspend, recovery code (`select` only) |
| P7-03 | Printable QR re-issue with a guest `select` |
| P7-04 | E-mail receipts (amount, restaurant, date, payment method) for the e-mail voucher flows; never a balance, voucher number, token or bearer link |

### Phase 8: fraud and risk engine (20–28 days) · depends on P3-04

| ID | Story |
|---|---|
| P8-01 | Aggregator: incremental windows (hour, day, week) per restaurant, employee, device, voucher and card |
| P8-02 | Baseline builder: nightly robust statistics (median, MAD) per metric and hour-of-week bucket; warm-up defaults; versioned baselines |
| P8-03 | `RiskModel` interface; `RuleModel` (versioned, parameterised rules, per-restaurant tightening within platform bounds); `BaselineAnomalyModel` (deviation, peer comparison, novelty) |
| P8-04 | Synchronous pre-check (< 20 ms target) on sale, activation, bind, replacement, redemption, reload and reversal: allow, flag, require approval, or block, with reasons |
| P8-05 | Asynchronous scoring; `risk_assessments` (append-only: model version, feature snapshot, score, reasons) |
| P8-06 | Alerts (dashboard, immediate e-mail for high and critical, digests), de-duplication, platform-level alerts for cross-restaurant patterns |
| P8-07 | Investigation cases: grouping, assignment, notes, resolution labels (`fraud`, `legitimate`, `inconclusive`); append-only case events; owner dashboard with the complete trail |
| P8-08 | Explainability: plain-language reasons on every alert and case |
| P8-09 | Staff notice text and the legal-basis setting per restaurant (works council / consent, GDPR purpose and retention); retention jobs |
| P8-10 | Shadow-mode hook for a later ML model: feature vectors and labels exported for training; model registry entry with version |

### Phase 9: production readiness (12–16 days)

| ID | Story |
|---|---|
| P9-01 | Certificate pinning to the ISRG roots with a backup pin (both platforms) |
| P9-02 | Nightly off-site anchor of the chain heads (object-lock bucket + owner e-mail) |
| P9-03 | Separate database users: migrator (DDL) vs application (no UPDATE/DELETE on append-only tables); Coolify start-up changed accordingly |
| P9-04 | Operations findings from the audit: backups (B2: prune only after success, off-site encrypted copy, heartbeat), failed-migration safety (D3), real worker health checks (D4), external monitoring (D5), graceful deploys (D6), 4 GB + swap |
| P9-05 | Cash reconciliation report |
| P9-06 | Runbooks (architecture §19) |
| P9-07 | Penetration test and its fixes; cryptographic review and its fixes |
| P9-08 | Restaurant onboarding guide, staff training material, guest terms (anonymous card = cash) |

### Phase 10: online shop (15–20 days)

As specified in architecture §11.3:
- connected accounts (restaurant = merchant of record);
- signed webhooks with account, amount and currency checks;
- refunds (block first) and disputes;
- the 24-hour cap without card binding;
- fraud rules through the risk engine.

### Effort summary

| Phases | Days |
|---|---|
| 0 Security foundation | 26–35 |
| 1–9 | 101–137 |
| **Complete platform** | **127–172** |
| 10 Online shop | 15–20 |
| **With online shop** | **142–192** |

These are engineer-days, not calendar time. With two engineers, the complete platform takes about 7–9 months of calendar time, including reviews, supplier lead times and the penetration test **[Assessment]**. There is no date to meet. Phases end when their acceptance criteria are met.

---

## 5. Items outside engineering (start now)

| # | Item | Owner | Needed before |
|---|---|---|---|
| L2 | Google Cloud organisation, staging and production projects, EU region, HSM, IAM | Product owner + engineering | Phase 1 |
| L3 | Key ceremony: three custodians, air-gapped laptop, script, safes, witness | Product owner | Production ceremony before the first real batch |
| L4 | Tap domain `t.giftcardpro.at`: 10-year renewal, registrar lock, TLS and uptime monitoring | Product owner | Phase 3 |
| L5 | 100 blank NTAG 424 DNA lab cards (genuine NXP); premium card supplier (quote, artwork, minimum quantity, lead time) | Product owner | Lab cards before Phase 4; supplier before the first batch |
| L6 | Test devices: 5 Android (including a low-end one), 3 iPhone (XS or newer) | Product owner | Phase 4 |
| L7 | Apple: signing certificates and App Store Connect API key for CI (account exists) | Product owner | P0-12 |
| L8 | Legal opinion: anonymous cards as cash, expiry, VAT, maximum value, online withdrawal, **employee monitoring by the risk engine** (works council / consent, GDPR impact assessment) | Product owner | Phase 8 and before the first restaurant |
| L10 | First restaurant and its branded batch | Product owner | After Phase 9 |
| L11 | External penetration test | Product owner | Phase 9 |
| L12 | External cryptographic review | Product owner | After Phases 1, 4 and 6 |

---

## 6. Quality

### 6.1 Test levels

| Level | Content |
|---|---|
| Unit | Crypto with NXP vectors; limits; lifecycle transitions; risk rules and baseline statistics |
| Feature and abuse | Every endpoint; every forbidden path; every invariant of architecture §13.2 as a named test |
| Concurrency | Parallel redemptions; parallel binds; parallel batch transitions; chain serialisation |
| End-to-end | Dashboard scripts; Flutter integration tests on both platforms |
| Hardware | §6.3 matrix with lab cards |
| Security | Penetration test; cryptographic review; dependency and secret scanning in CI |
| Load | Staging with the real HSM: 20 taps per second for 10 minutes, p95 server time < 300 ms; risk pre-check p95 < 20 ms **[targets]** |
| Resilience | Crypto service or HSM down; database restart; mail down: clean refusals, nothing half-written |

### 6.2 Release gates

| Gate | Condition |
|---|---|
| Every merge | CI green: tests, abuse suite, vectors, static analysis, grep checks (no removed concepts, no `NTAG424_*` env, no card `id` in resources), Android and iOS builds |
| Staging release | Schema migrations applied on a fresh database and on staging |
| Production | Second sign-off; rollback plan; release notes |
| First restaurant | §7 checklist |

### 6.3 Hardware matrix

| Actions \ devices | 5 Android models (incl. low-end) | 3 iPhones (XS or newer) |
|---|---|---|
| Redeem (live authentication), QR redeem | ✓ | ✓ |
| Sell, bind, add card, replace, register, receive, card info | ✓ | ✓ |
| Guest tap (balance page) | ✓ (Chrome) | ✓ (background reading) |
| Card lifted early, retry | ✓ | ✓ |
| Station personalisation | Station phone only | — (internal tool) |

---

## 7. First-restaurant checklist

**Security**
- [ ] Abuse suite green; penetration test without open high or critical findings; cryptographic review closed
- [ ] Production key ceremony done; KCVs recorded; components in two safes
- [ ] HSM IAM least privilege; append-only enforcement with separate DB users; nightly verification and off-site anchors running
- [ ] Risk engine live with baselines in warm-up; alerts reach the owner; staff notice given (L8)

**Product**
- [ ] First batch released and received by count + tap
- [ ] Android and iPhone apps in the stores (or TestFlight / internal testing for the first restaurant), feature parity verified on the matrix
- [ ] Guest terms (anonymous card = cash); staff trained

**Operations**
- [ ] Runbooks and the crypto-outage drill; backups off-site with a tested restore; monitoring and alerting; tap domain protected

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Card supply (artwork, minimum quantity, lead time) | L5 early; lab cards from stock |
| iOS NFC or App Review surprises | iOS CI from Phase 0; iOS relay built together with Android (P4-01/02) |
| Google raw-encryption import procedure | Staging ceremony as a rehearsal in Phase 1 |
| Personalisation bugs lock lab cards | 100 lab cards; deterministic keys; recovery journal |
| Relay latency on weak networks | Measured in P4-04 on both platforms |
| Crypto knowledge in one person | Second review of every crypto change; external review |
| Employee-monitoring law for the risk engine | L8 before Phase 8 goes live; staff notice and legal-basis setting in the product |
| Scope growth | Change rule: proposals first, then an ADR |
