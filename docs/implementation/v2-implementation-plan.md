# GiftCard Pro v2: implementation plan

| | |
|---|---|
| **Date** | 28 September 2026 |
| **Baseline** | `docs/architecture/giftcard-pro-v2-architecture.md`, **frozen v2.1** (ADR-000 + ADR-001) |
| **Rule** | This plan implements the frozen architecture. It adds no architecture. Anything that would change a table, a flow, a trust boundary or a security control needs an ADR first (architecture §20). |
| **Code base** | Code at commit `0493784` (unchanged since); file:line references below are to that version. |

---

## 1. What this plan delivers

1. **Phase 0 (highest priority):** within about two weeks, no path remains that spends from a card voucher without a verified NTAG 424 DNA card.
2. **Phase 0B:** every activation is linked to a payment record, and audit logs become append-only and tamper-evident.
3. **Phases 1–9:** the v2 physical-card platform:
   - Google Cloud HSM;
   - central personalisation;
   - bind by tap;
   - live authentication;
   - lifecycle and batches;
   - digital QR vouchers as a separate product;
   - pilot readiness.
4. **Phase 10:** the online shop (after the pilot).

### 1.1 What the product can and cannot do in between

This follows directly from decisions 21–23, and it must be communicated to pilot restaurants **before** Phase 0 goes live:

| Period | Selling | Redeeming |
|---|---|---|
| **After Phase 0, before Phase 5** | **Digital QR vouchers only.** No new physical cards can be sold, because NTAG21x issuing is off and 424 binding does not exist yet. | Digital vouchers by QR. Existing NTAG 424 cards (if any) by verified tap. **Existing NTAG21x card balances are frozen, not lost**, until the swap exists. |
| **After Phase 5–6** (lab cards) and the first accepted batch | Premium NTAG 424 cards + digital vouchers | Cards by live tap; digital by QR; legacy cards swapped at the counter |

**Consequence for the 3 November 2026 launch target:**
- If the launch goes ahead on that date, it is a **digital-voucher launch** (after Phase 0 and the audit blockers).
- Premium physical cards follow when Phases 1–6 and the first batch are done (§8: about 16–17 weeks after start with two engineers).
- **Decision needed (§13, item 1):** how many real vouchers with a balance sit on NTAG21x cards in production today. If there are any, their holders must be told that the balance is safe and will be moved to a premium card.

---

## 2. Team, environments and working rules

### 2.1 Team

The plan assumes **two engineers**. More people shorten the phases in parallel tracks only; the critical path (§8) is sequential.
- **Engineer A:** backend and crypto service.
- **Engineer B:** Flutter app, native NFC and dashboard.
- **Product owner:** long-lead items, legal, supplier, pilot restaurant.

### 2.2 Environments

| Environment | Keys | Data | Purpose |
|---|---|---|---|
| Local | Software keys (T1 envelope, test values from NXP application notes) | Seeded | Development, NXP test vectors |
| **Staging** | **Separate Google Cloud project + HSM key ring**, staging key set (never used for real cards) | Anonymised production copy for migration rehearsals | Integration, hardware tests with lab cards, penetration test |
| Production | Production key ring after the key ceremony; production key set | Live | Pilot |

Lab cards personalised with the staging key set can **never** work in production (different key set, different roots). They are marked with a sticker, and the production batch acceptance refuses them.

### 2.3 Working rules

- **Feature flags per restaurant** for every behaviour change (list in §9.4). Defaults are secure; the pilot is enabled explicitly.
- **Migrations are additive** until the removal steps (architecture §16.3). Every migration has a tested rollback, or is declared forward-only with a reason.
- **No secrets in `.env` for card keys** from Phase 1 on. CI fails if an `NTAG424_*` variable is set in any non-local environment file.
- **Every security rule has an abuse test.** It tries the forbidden path and must be refused. Abuse tests live in `tests/Feature/Abuse/` and run in CI.

### 2.4 Definition of done (every story)

1. Code, unit and feature tests; abuse tests for any security rule.
2. Audit events for every privileged action; no secret or UID in logs.
3. API and error codes documented (`docs/API.md`), plus the owner or staff documentation where the workflow changes.
4. Migration forward and rollback tested on a production copy (stories with schema changes).
5. The feature flag works in both states.
6. Reviewed by the second engineer. Crypto code is additionally checked against the NXP test vectors and listed for the external cryptographic review.

---

## 3. Long-lead items: start in week 1

| # | Item | Owner | Needed by | Notes |
|---|---|---|---|---|
| L1 | **Production data check:** vouchers with balance > 0 per `nfc_tag_type` (ntag21x / ntag424 / qr_only / null) | Engineer A | Before Phase 0 go-live | One read-only query; decides the communication in §1.1 |
| L2 | Google Cloud organisation, **two projects** (staging, production), EU region, Cloud KMS + HSM enabled, IAM with least privilege, billing | Product owner + A | Week 3 | Service account only for the crypto service |
| L3 | **Key ceremony** preparation: three custodians named, air-gapped laptop, script, safes, witness | Product owner | Week 6 (production ceremony before the pilot batch) | Staging uses a lighter ceremony |
| L4 | Register **`t.giftcardpro.at`** tap subdomain; the parent domain on 10-year auto-renewal with registrar lock; TLS and uptime monitoring | Product owner | Week 4 | Permanent: cards carry it for life |
| L5 | **Blank NTAG 424 DNA cards for the lab** (100, with genuine NXP chips) and a **premium card supplier** (quote, artwork, minimum quantity, lead time, personalisation capability for later) | Product owner | Lab cards week 4; supplier contract week 8 | Lead time is the biggest schedule risk |
| L6 | **Test devices:** 5 Android models (including a low-end one) and 3 iPhone models (XS or newer) | Product owner | Week 4 | NFC antenna positions vary; the hardware matrix is in §9.3 |
| L7 | **Apple Developer account**, iOS signing, NFC tag-reading capability, TestFlight | B | Week 3 | **The app has never been built for iOS**; first build and review are a risk |
| L8 | **Legal opinion:** anonymous cards as cash (T&C wording), expiry (including existing 36-month vouchers), VAT (single-purpose voucher), maximum value, withdrawal (online, Phase 10) | Product owner | Before the pilot | Blocker 1 and 11 of the audit |
| L9 | Payment-provider choice (Stripe or Mollie Connect) | Product owner | Week 10 (Phase 10 only) | Not on the pilot's critical path |
| L10 | **Pilot restaurant** and its first branded batch (quantity, artwork) | Product owner | Week 8 | — |
| L11 | External **penetration test** booked | Product owner | Slot in weeks 14–16 | — |
| L12 | External **cryptographic review** booked (Phases 1, 4, 6) | Product owner | Slot in weeks 11–13 | — |

---

## 4. Phase 0: no spending without a verified NTAG 424 DNA card

**Goal.** From go-live of Phase 0, a card voucher can only be debited after its genuine NTAG 424 DNA chip was verified by the server in the same minute, on the same device, by the same user. Digital QR vouchers keep working as the separate product. Everything else is refused.

**Effort:** 6–8 engineer-days (≈ 1 calendar week with two engineers).

### 4.1 Every current path to money, and its fix

| # | Path today | Evidence **[Code]** | Phase 0 fix |
|---|---|---|---|
| P1 | `POST /cards/{card}/redeem` with any known card id, no proof of presence | `routes/api.php:79`, `GiftCardActionController.php:49` | Requires `scan_ticket_id` (§4.3). No ticket, no debit. |
| P2 | `POST /cards/{card}/transfer` moves value to another card | `routes/api.php:81`, `GiftCardService.php:278` | **Disabled** (`FEATURE_DISABLED`). v2 has no transfers (architecture R25). |
| P3 | `POST /cards/{card}/replace` creates a new card with a new QR token and moves the balance there, turning a card voucher into a QR-spendable one | `routes/api.php:87`, `GiftCardService.php:367–431` | **Disabled.** Replacement returns in Phase 5 as bind-by-tap. |
| P4 | `POST /scan` with `method: qr`, `link`, `manual` or `api` resolves a card voucher without its chip | `CardScanService.php:73`, `:84–93` | Lookup may still work (managers only for `manual`), but the ticket is **never spend-enabled** for a card voucher unless the method was a verified 424 tap (§4.2). |
| P5 | NTAG21x tap: static URL + UID reported by the client | `CardScanService.php:161–177` | **Never spend-enabled** (decision 22). The response says "legacy card: balance safe, swap required". |
| P6 | Waiter types the card number | `ScanCardRequest.php:23`; waiter permissions `RoleSlug.php:73–76`; app `s11_manual_entry.dart` | Waiters: `manual` refused. Managers: lookup only, never spend-enabled. The app hides manual entry for waiters. |
| P7 | A 424 voucher "marked as provisioned" is bound to the first chip that taps it (trust on first use); today all 424 cards share one global key pair from `.env` | `NfcProgrammingService.php:231–250`, `CardScanService.php:139`, `config/giftcard.php:43–44` | `bindUnverified` **off**. **Binding at scan time is removed** (the `?? $message->uid` in the counter update), so a 424 voucher without a bound UID stays unbound. It is neither spend- nor reload-enabled; L1 finds such vouchers and they are handled individually. |
| P8 | NFC programming endpoints (write, check, lock, attempts, QR payload) | `routes/api.php:88–97` | **Disabled** (decision 23); read-only history stays. |
| P9 | New vouchers created active with any tag type | `IssueGiftCardData.php:23–24, 43–44`; `GiftCardService.php:103` | `POST /cards` accepts only `nfc_tag_type = qr_only` (digital) until Phase 5. Activation needs payment (Phase 0B). |
| P10 | Platform admin acting in a tenant (`X-Restaurant-Id`) | `ResolveTenant.php:44–45` | Same rules, no exception. Every tenant action by a platform admin is audited with the real user. |
| P11 | API tokens with `cards.redeem` (POS integrations) | `ApiTokenService.php` | Same rules: they need a spend-enabled ticket, which needs a verified 424 tap or a digital QR. |
| P12 | Web terminal in the dashboard (Web NFC, QR, manual) | `dashboard/src/components/waiter/terminal.tsx:79–392` | Manual entry removed; carries the ticket; NTAG21x shows "swap required". |
| P13 | `link` method (an iPhone opened the tag URL) | `CardScanService.php:73` | For card vouchers, **not spend-enabled**, because there is no RF UID. Spending requires the app's NFC session. |
| P14 | Reversals: of a redemption (a credit back to the voucher), or of a reload (an **administrative debit**) | `routes/api.php:103`, `GiftCardService.php:433–457`, `TransactionType.php:38–41` | Not a customer spend path. It stays manager/owner-only with a reason, becomes append-only in Phase 0B (§5.3), and appears in the owner report. It is excluded from the "debit needs a ticket" check, which applies to **redemptions**. |
| P15 | A card-number lookup sent with another method (e.g. `method: qr` + `card_number`) is resolved as if it were that method | `CardScanService.php:84–93`, `ScanCardRequest.php:22–23` | **Spend permission is decided by how the card was found, not by the declared method.** A number lookup is never spend-enabled, and `card_number` is refused unless `method = manual`. |
| P16 | Expiry write-offs: `POST /cards/{card}/expire` and the nightly job debit the balance as `expiration` | `routes/api.php:86`, `routes/console.php:27`, `GiftCardService.php:531–553, 696–723` | Not a customer spend path, but audit blocker 1: **the automatic write-off is paused for all vouchers** until the legal opinion (L8). Manual `expire` becomes owner-only with a reason, behind the flag. |
| P17 | Reload onto a legacy or unbound 424 voucher (value added to a balance that cannot be spent) | `GiftCardService.php:215–271` | Refused in Phase 0 (`LEGACY_CARD_SWAP_REQUIRED`) |

### 4.2 Spend rules (the only allowed combinations)

A voucher's kind is derived from today's data until Phase 2 introduces `gift_cards.kind`. Spend permission is decided by **how the card was found** (a verified tap, a QR token or a number lookup), never by the `method` the client declares (P15):
- `nfc_tag_type = ntag424_dna` with a bound UID → **card (424)**; without a bound UID → **unbound 424**, which is neither spendable nor reloadable (P7);
- `ntag213/215/216` → **legacy card**;
- `qr_only`, or no tag type and no UID → **digital**. `POST /cards` normalises a missing tag type to `qr_only`.

| Voucher kind \ scan method | `nfc` with valid SUN + RF UID | `nfc` without SUN | `link` | `qr` | `manual` | `api` |
|---|---|---|---|---|---|---|
| Card (424) | ✅ spend | ❌ | ❌ lookup only | ❌ | ❌ (managers: lookup) | ❌ |
| Legacy card | — | ❌ swap required | ❌ | ❌ | ❌ (managers: lookup) | ❌ |
| Digital | — | — | ✅ spend | ✅ spend | ❌ (managers: lookup) | ❌ |

**"Valid SUN" in Phase 0** means everything today's code checks, plus the RF UID rule:
- MAC verified;
- counter strictly greater (compare-and-set, `CardScanService.php:134–139`);
- PICC UID = bound UID;
- **and new:** RF UID reported by the reader = PICC UID (gap G8 in `ntag424-platform-architecture.md` §2).

Live AES authentication replaces this as the card rule in Phase 4.

### 4.3 Scan tickets (the Phase 0 form of presentments)

- **Table `scan_tickets`:**
  - `id` UUIDv4, `restaurant_id`, `gift_card_id`, `user_id`, `device_id`;
  - `method`, `verification (sun, qr)`, `sdm_counter`, `spend_allowed`;
  - `created_at`, `expires_at` (60 s), `consumed_at`, `consumed_by_transaction_id`.
- **`POST /scan`** returns `scan_ticket: {id, expires_at, spend_allowed}` next to the card.
- **Redeem** requires `scan_ticket_id`. In one transaction:
  1. existing idempotency lookup first, so a retry after success returns the original result;
  2. `UPDATE scan_tickets SET consumed_at = now() WHERE id = ? AND consumed_at IS NULL AND expires_at > now() AND spend_allowed AND user_id = ? AND device_id <=> ? AND restaurant_id = ? AND gift_card_id = ?` (null-safe device comparison, so API tokens and sessions without a device header behave consistently). Zero rows → `TICKET_INVALID`;
  3. ledger entry with `scan_ticket_id` (new nullable column on `gift_card_transactions`, **unique**);
  4. commit.
- In Phase 2–3 tickets are generalised into `presentments`; the column and the rule stay.

### 4.4 Changes per component

| Component | Changes |
|---|---|
| Backend | `scan_tickets` migration and model; `ScanTicketService`; ticket issuance in `CardScanService` (rules of §4.2, RF UID check); a new `RedeemRequest` (split from `MoneyOperationRequest`, which reload keeps) requires `scan_ticket_id`; transfer, replace, NFC-programming and QR-payload routes behind the `v2_phase0_spend_rules` flag returning `FEATURE_DISABLED`; `manual` scans refused for waiters; `POST /cards` digital-only; new error codes `TICKET_REQUIRED`, `TICKET_INVALID`, `SPEND_REQUIRES_VERIFIED_CARD`, `LEGACY_CARD_SWAP_REQUIRED`, `FEATURE_DISABLED` |
| Waiter app 1.5.0 | Carries the ticket into redeem. Manual entry hidden for waiters (lookup-only for managers). Legacy card message: "balance safe, swap coming". S20 (sell + NTAG21x programming) hidden behind the flag. New error texts (copy document §5). |
| Dashboard | Programming station, NFC writer and QR payload hidden. New-card form: digital voucher only. Print page: digital vouchers only, **no card number printed**. Web terminal: no manual entry, carries the ticket, legacy message. |
| Configuration | `app.min_version.android` = 1.5.0 at go-live, so older apps must update. The server enforces the rules either way. |

**Phase 0 stories:**

| ID | Story |
|---|---|
| P0-01 | `scan_tickets` + `ScanTicketService`; spend rules by how the card was found (§4.2, P15); RF UID check |
| P0-02 | Redeem requires a ticket (`RedeemRequest`); `scan_ticket_id` unique on the ledger |
| P0-03 | Disable transfer, replace, NFC programming and QR payload (flag); `bindUnverified` off; no binding at scan time |
| P0-04 | `POST /cards` digital-only; reload refused on legacy/unbound vouchers; manual `expire` owner-only; automatic write-off paused |
| P0-05 | Waiter app 1.5.0 (ticket, no manual entry for waiters, legacy message, S20 hidden) |
| P0-06 | Dashboard (no programming, digital-only sale, print page without number, web terminal) |
| P0-07 | Idempotency key re-checked under the row lock (audit blocker 2) |
| P0-08 | App uncertain-outcome handling (audit blocker 3) |
| P0-09 | Scan lockout keyed per restaurant + IP + user (audit blocker 7) |
| P0-10 | Abuse suite (§4.5) |

### 4.5 Abuse tests (all must be refused; `tests/Feature/Abuse/Phase0Test.php`)

1. Redeem without ticket, with an expired ticket, with a consumed ticket, with another user's or device's ticket, and with a ticket for another card.
2. Redeem after `scan` with `qr`, `link`, `manual` and `api` on a 424 card voucher.
3. Redeem after an NTAG21x tap.
4. 424 tap with a valid SUN but an RF UID different from the PICC UID (HCE emulation); replayed SUN URL (counter not greater).
5. Waiter `manual` scan; manager `manual` scan followed by redeem.
6. Transfer, replace, NFC bind/check/lock/attempts, QR payload: all `FEATURE_DISABLED`.
7. `POST /cards` with `nfc_tag_type = ntag215` or `ntag424_dna`; reload on a legacy card; `method: qr` with a `card_number`; first SUN tap on an unbound 424 voucher (must not bind).
8. Platform admin with `X-Restaurant-Id` and an API token with `cards.redeem`: same refusals.
9. Two parallel redeems with the same ticket: exactly one succeeds (concurrency test, like the existing ledger tests).
10. **Positive:** digital voucher by QR; 424 card by verified tap; idempotent retry after a lost response returns the original result.

### 4.6 Rollout and acceptance

1. L1 data check; communication to restaurants (§1.1).
2. Deploy with the flag off. Enable on staging and run the abuse suite plus a manual test with a real NTAG 424 card and an NTAG215 card.
3. Enable in production for all restaurants (pre-launch, so no gradual rollout is needed). Raise the minimum app version.
4. **Accepted when:**
   - the abuse suite is green in CI;
   - a manual retest by the second engineer is done;
   - in production, **zero redemption** entries without `scan_ticket_id` for 14 days (a daily query, then the nightly verifier from 0B; administrative entries such as reversals are reported separately);
   - no increase in support tickets beyond legacy-card questions.

---

## 5. Phase 0B: payment records and immutable audit (4–6 days)

**Phase 0B stories:**
- P0B-01: payments;
- P0B-02: append-only + chains + verifier;
- P0B-03: no default expiry.

### 5.1 Payment record for every activation (decision 25)

- **Table `payments`:**
  - `id`, `restaurant_id`, `gift_card_id`;
  - `method (cash, card_terminal, online_psp, bank_transfer, complimentary, legacy_unrecorded)`;
  - `amount`, `currency`, `reference` (terminal receipt number, provider payment id or transfer reference);
  - `received_by`, `device_id`, `approved_by` (complimentary), `created_at`.
- **Rules:**
  - `POST /cards` with `activate = true`, `POST /cards/{card}/activate` and `POST /cards/{card}/reload` require a payment object; the amount must equal the value or reload;
  - `complimentary` requires the owner role and a reason (four-eyes when the seller is not the owner);
  - backfill: every existing voucher gets one `legacy_unrecorded` payment, reported separately and never creatable by the API.
- **UI:** a payment-method selector in the dashboard sale and reload forms (the app's S20 is hidden until Phase 5).
- **Report:** sales by payment method per day, which feeds the cash reconciliation in Phase 9.

### 5.2 No default expiry (audit blocker 1)

New vouchers get **no expiry** by default (today: 36 months, `RestaurantSetting.php:44`). Existing expiries stay unchanged until the legal opinion (L8) says how to handle them. The nightly expiry job is paused for vouchers sold after this change.

### 5.3 Audit logs and ledger: append-only and tamper-evident

- **Triggers** that reject `UPDATE` and `DELETE` on `audit_logs` and `gift_card_transactions`. Today `reverse()` sets `reversed_at` on the original entry (`GiftCardService.php:474`). Instead, "reversed" becomes derived from the reversal entry (`related_transaction_id`, **unique** for reversal entries), and `reversed_at` is frozen.
- **Hash chain** per restaurant on both tables: `chain_seq`, `prev_hash`, `entry_hash = SHA-256(canonical row ‖ prev_hash)`, serialised by a row lock on a `chain_heads` row.
- **`giftcard:verify-chains` command** (nightly): recomputes chains and balances, and checks that no redemption exists without a ticket or presentment. Any difference raises a critical alert.
- **Database users:** separating the migrator user from the application user (so the app user has no UPDATE/DELETE grant on these tables and no DDL) needs a change to the Coolify start-up, which runs migrations with the app user today. **Scheduled in Phase 9** (P9-03). Until then, the triggers plus the chain make tampering detectable, not impossible.

---

## 6. Phases 1–10

Effort is for one engineer **[Assessment]**. IDs are used for tracking.

### Phase 1: crypto service and Google Cloud HSM (10–14 days, engineer A)

**Depends on:** L2.

| ID | Story | Accepted when |
|---|---|---|
| P1-01 | Crypto service skeleton: its own container in the Coolify stack, mTLS to the API, its own service account, no database, structured audit log to a separate sink | Deployed on staging; the API reaches it only with its client certificate |
| P1-02 | AES-CMAC and AN10922 (32-byte padding + subkey K2) and AN12196 SUN session keys: pure functions with NXP's published vectors | All NXP vectors pass in CI |
| P1-03 | HSM adapter: imported AES roots; CMAC composed from raw AES-CBC with caller IV (Google raw encryption, imported keys only) | Derived test keys equal the software reference for 1 000 random UIDs |
| P1-04 | Operations `sun.verify`, `auth.begin` / `auth.finish` (RndA inside the service, 30 s, single use), `perso.*` (station identity, approved batch only); rate limits per caller and chip | Contract tests; abuse tests (reuse of a challenge, wrong identity for `perso.*`) |
| P1-05 | Key sets and key references (metadata + KCV only), ceremony script, and the **staging** ceremony | Staging key set active; KCVs match the HSM |
| P1-06 | Remove the 424 keys from `.env`; import the legacy key pair as key set v0 **only if** L1 found 424 cards in circulation (architecture R14) | CI check that no `NTAG424_*` variable is set; v0 path built or explicitly skipped |
| P1-07 | Two instances, health checks, alerting on error rate and unusual volume | Alert fires in a staging drill |

### Phase 2: schema and backfill (7–10 days, engineer A)

**Depends on:** Phase 0B. **Parallel to:** Phase 1.

| ID | Story | Accepted when |
|---|---|---|
| P2-01 | `gift_cards.kind` (`card`, `digital`), statuses `awaiting_card`, `cancelled`, `closed`; `card_number` documented as the internal voucher number | Backfill per §4.2 rules; counts reconcile |
| P2-02 | `cards` (id **UUIDv4 via `HasVersion4Uuids`**, never serialised; `card_number` inventory number; uid; chip_type; batch; key set; state; counters) with a CHECK constraint on state; `card_events` append-only | A model test proves `id` is not in any API resource (global serialisation test) |
| P2-03 | `card_batches` with the fields of architecture §8.1, and the counts view | View returns the §8.3 buckets; reconciliation check |
| P2-04 | `media` (nfc_card, email_voucher, printable_qr, legacy_token), `contacts`, `contact_confirmations`, `authorizations` | Migration of existing tokens into `legacy_token` (hash only), plain column cleared behind a flag |
| P2-05 | `presentments` (generalises `scan_tickets`; the unique link on ledger rows stays) | Phase 0 abuse suite still green |
| P2-06 | Migration rehearsal on an anonymised production copy, with forward, rollback and timings | Report attached to the release |

### Phase 3: presentment service, SUN v2 and tap domain (7–10 days, engineer A)

**Depends on:** Phases 1 and 2.

| ID | Story | Accepted when |
|---|---|---|
| P3-01 | `PresentmentService` with purposes (`spend`, `bind`, `select`, `receive`, `resume`, `verify`), methods, voucher-kind rules, 60 s single use | Unit and abuse tests per purpose |
| P3-02 | SUN v2 URL `https://t.giftcardpro.at/{k}?e=…&m=…`, MAC over the URL part (architecture §9) | Lab card verifies; a tampered URL fails |
| P3-03 | Guest balance page on the tap domain (SUN verified, throttled, restaurant can disable) | iPhone background read and Android open it |
| P3-04 | Limit model (§6.3 of the architecture) and risk rules 1–8 (synchronous) + nightly report | Tests at every boundary value |
| P3-05 | `CardLifecycle` service with the transition table (architecture §7.2); the only writer of `cards.state` | A static check forbids direct updates of `state`; transition tests |

### Phase 4: live authentication and native relay (12–16 days, engineer B, with A for the server part)

**Depends on:** Phase 1. It is split so that the station (Phase 6) can start early:

| ID | Story | Accepted when |
|---|---|---|
| P4-01 | **Android relay:** `IsoDep` channel `relayOpen` / `transceive` / `relayClose`; the four fixed commands; nothing stored | Instrumented test on a real card |
| P4-02 | **iPhone relay:** first iOS build (L7), `NFCTagReaderSession` ISO 14443 → `NFCISO7816Tag.sendCommand` | TestFlight build reads a lab card |
| P4-03 | Server protocol `POST /presentments` + `/complete` with `auth.begin` / `auth.finish` | End-to-end on staging with lab cards |
| P4-04 | Latency measurement on the device matrix (§9.3) | p95 card-in-field < 0.8 s on all devices, or a documented exception |
| P4-05 | Card spending switches from the Phase 0 SUN rule to **live authentication only** (flag per restaurant, default on for new restaurants) | Abuse test: SUN-only spend is refused once the flag is on |

### Phase 5: restaurant workflows (13–17 days, engineer B + A)

**Depends on:** Phases 3 and 4.

| ID | Story | Accepted when |
|---|---|---|
| P5-01 | **Sell voucher** (app): payment method → amount → optional e-mail → tap an available card → active. Also "digital voucher" and "printable" forms. Reuses the S20 `IssueController`. | E2E: the voucher is active only with a payment and a bound card |
| P5-02 | **Add card to voucher** (select + bind; converts a digital voucher, decision 26) | The QR media of the voucher are revoked in the same transaction (test) |
| P5-03 | **Replace card** (lost, damaged or unreadable): old-card `select`, or recovery code / `email_link`; 72 h cap; owner approval when the seller is the same user | Abuse tests: no recovery for anonymous vouchers; staff cannot replace the guest's proof |
| P5-04 | **Register card** at the counter (card tap + e-mail confirmation), change of contact | Old address notified; tap required |
| P5-05 | **Receive cards** (count + tap, `on_hold` with per-card check-in) and **Card info** | A mismatch never makes missing cards `available` |
| P5-06 | Step-up: device-bound biometric key (Android Keystore / Secure Enclave), or server-verified PIN on shared phones | Server rejects step-up proofs that are replayed or come from another device |
| P5-07 | Four-eyes approvals (sales above the threshold, complimentary vouchers, recovery approvals) | Approval and rejection paths |
| P5-08 | Dashboard: vouchers with media and card lifecycle, batches and stock, owner reports (replacements, risk events, payments by method) | Owner and manager views; no card `id` visible anywhere |

### Phase 6: central personalisation and batches (10–14 days, engineer A + B)

**Depends on:** P1-04 and P4-01. **Starts before P4-03**, so that lab cards exist for the live-authentication tests.

| ID | Story | Accepted when |
|---|---|---|
| P6-01 | Station mode in the app (`station_operator` role, enrolled station device only): intake (originality signature), personalisation steps, per-card outsider QA | 100 lab cards personalised; failures go to `qa_failed` |
| P6-02 | Recovery of interrupted personalisation (deterministic keys, step journal) | Pulling the card mid-process and retrying works in 20 of 20 attempts |
| P6-03 | Platform admin: batches (create, approve with two people, ship, deliver, compromise playbook) | Batch state changes move all cards (§8.2 mapping) |
| P6-04 | Manufacturer manifest import and sample acceptance | **Deferred** until the first manufacturer batch; in-house for the pilot |

### Phase 7: legacy migration and code removal (4–6 days)

| ID | Story |
|---|---|
| P7-01 | Legacy card swap (tap the old NTAG21x card as `select`, bind a new 424 card); owner list of legacy balances; guest invitations |
| P7-02 | Delete the writer code (≈ 6 700 lines, architecture §3.4), the print page's card-number output, and replace-by-transfer, one stable release after P5 |
| P7-03 | Sunset jobs (T0 + 9 months notice, T0 + 12 months legacy digital links view-only) |

### Phase 8: digital vouchers v2 (4–6 days)

| ID | Story |
|---|---|
| P8-01 | E-mail voucher page, device confirmation code, rotating QR (spending, digital vouchers only) |
| P8-02 | Recovery-contact page for card vouchers: balance, receipts, suspend, recovery code (`select` only) |
| P8-03 | Printable QR (digital only, one active, re-issue with a guest `select`) |
| P8-04 | Rewritten e-mail templates: no balances, no voucher numbers, no bearer links (architecture C13) |

### Phase 9: pilot readiness (8–12 days)

| ID | Story |
|---|---|
| P9-01 | Certificate pinning to the ISRG roots with a backup pin (app) |
| P9-02 | Nightly off-site anchor of the chain heads (object-lock bucket + owner e-mail) |
| P9-03 | **Separate database users:** migrator (DDL) vs application (no UPDATE/DELETE on append-only tables); Coolify start-up changed accordingly |
| P9-04 | Cash reconciliation report (declared cash vs cash sales per day) |
| P9-05 | Runbooks (architecture §19) |
| P9-06 | Penetration-test fixes (the test runs in weeks 13–15) |
| P9-07 | Restaurant onboarding guide, staff training material, guest T&C wording (L8) |

### Phase 10: online shop (15–20 days, after the pilot)

The architecture §11.3 as specified:
- connected accounts (restaurant = merchant of record);
- signed webhooks with account, amount and currency checks;
- refunds (block first), disputes;
- the 24-hour cap and no card binding in that window;
- fraud rules.

### Effort summary

| Phases | Days |
|---|---|
| 0 + 0B | 10–14 |
| 1–9 (pilot scope) | 75–105 |
| **Pilot total** | **85–119** |
| 10 (online shop) | 15–20 |
| **Total** | **100–139** |

The architecture's §17 points to these figures (ADR-001): the override work is gone, and payments and audit immutability moved forward into 0B. Track B (§7) comes on top.

---

## 7. Launch blockers from the audit

The investor-grade audit (`docs/reports/2026-09-28-investor-grade-audit.md`) listed 11 blockers. Each has a home:

| # | Blocker | Where it is fixed |
|---|---|---|
| 1 | 36-month expiry unlawful for paid vouchers | **Phase 0B** (P0B-03: default "no expiry" for new vouchers) + L8 for existing ones |
| 2 | Idempotency not re-checked under the row lock | **Phase 0** (the redeem path is rewritten anyway; P0-07) |
| 3 | Waiter app uncertain-outcome handling (double charge) | **Phase 0** app 1.5.0 (P0-08) |
| 4 | Platform-admin API tokens cross-tenant and unrevocable (S2) | **Track B** |
| 5 | Remember-me beats device revoke; password reset does not revoke tokens (S1, S3) | **Track B** |
| 6 | NTAG 424 check bypass via `method: qr/api` (S8) | **Phase 0** (the core of it) |
| 7 | Scan lockout per IP blocks all tenants behind one NAT (S7) | **Phase 0** (P0-09: throttle key per restaurant + IP + user) |
| 8 | Slow SMTP blocks php-fpm workers (F3) | **Track B** (mail always queued) |
| 9 | Backup failure prunes good dumps; no off-site copy (B2) | **Track B** (operations) |
| 10 | 2 GB server without swap; no health monitoring | **Track B** (operations) |
| 11 | Austrian lawyer review | **L8** |

**Track B** is 4–6 engineer-days (estimated from the audit's own hours for items 4, 5, 8, 9, 10). It is **not included** in §6's totals, and it runs in weeks 2–5 (§8).

**Phase 0 stories added by this mapping:**
- P0-07: idempotency key re-checked under the lock;
- P0-08: app uncertain-outcome handling;
- P0-09: per-tenant scan lockout;
- P0B-03: no default expiry.

They fit in the Phase 0/0B estimates because they touch the same code.

---

## 8. Schedule (two engineers)

| Week | Engineer A (backend, crypto) | Engineer B (app, dashboard) | Milestone |
|---|---|---|---|
| 1 | Phase 0 backend (tickets, rules, disabled routes, abuse suite) | Phase 0 app 1.5.0 + dashboard | — |
| 2 | Phase 0B (payments, append-only, chains, verifier) | 0B UI; Track B (tokens, sessions) | **M0: Phase 0 + 0B in production** |
| 3–5 | Phase 1 (crypto service, HSM, vectors, staging ceremony); Track B ops items (to week 5) | P4-01 Android relay; P4-02 first iOS build + relay | **M1 (wk 5):** crypto service on staging, vectors green, iOS TestFlight build |
| 5–6 | Phase 2 (schema, backfill, rehearsal) | P6-01/02 station mode (with A for `perso.*`) | — |
| 7–8 | Phase 3 (presentments, SUN v2, tap domain, lifecycle) | Personalise 100 lab cards; P4-03 client side | **M2 (wk 7):** lab cards personalised |
| 9–10 | P4-03 server, P3-04 limits and risk rules | P4-04 latency matrix, P4-05 | **M3 (wk 10):** live authentication end-to-end on Android + iPhone |
| 11–12 | Phase 5 server (bind, replace, register, receive, approvals); P6-03 batch admin | Phase 5 app + dashboard | Cryptographic review (L12) |
| 13 | P7-01 legacy swap; Phase 8 server | Phase 8 pages; P5-06 step-up polish | **M4 (wk 13):** feature-complete on staging |
| 14 | **Production key ceremony** (L3); pilot batch personalised and accepted | P9-01 pinning; P9-07 material | **M5 (wk 14):** pilot batch accepted |
| 14–16 | Penetration test (L11); P9 fixes, P9-02/03 | P9 fixes | — |
| 16–17 | Pilot go-live; P7-02 code removal one release later | Pilot support | **M6: pilot live with premium cards** |
| after | Phase 10 online shop | Phase 10 shop UI | — |

- **Critical path:**
  - L5 (branded blank cards on time);
  - P1-04 (personalisation operations) → P6-01 (station) → P4-03 (live auth);
  - then Phase 5 → penetration test → pilot.
- **About 16–17 weeks** from start to a pilot with premium cards, if L5 and L7 hold.
- **Slack:** none on the critical path. A two-week supplier delay moves the pilot by two weeks.

---

## 9. Quality

### 9.1 Test levels

| Level | Content |
|---|---|
| Unit | Crypto primitives with NXP vectors; limit and rule boundaries; lifecycle transitions (every allowed one, and a sample of forbidden ones) |
| Feature and abuse | Every endpoint; every forbidden path (`tests/Feature/Abuse/`); invariants of architecture §13.2 as named tests |
| Concurrency | Parallel redeems on one voucher/ticket; parallel binds of one card; parallel batch transitions (extends the audit's ledger stress test) |
| End-to-end | Dashboard (existing e2e scripts, extended); Flutter integration tests against staging |
| Hardware | §9.3 matrix, with real lab cards |
| Security | External penetration test; external cryptographic review; dependency and secret scanning in CI |
| Load | Staging with the real HSM: 20 taps per second sustained for 10 minutes, p95 server time < 300 ms **[target]** |
| Migration | Rehearsal on an anonymised production copy (P2-06), including rollback |
| Resilience | Crypto service killed during taps: card transactions refused cleanly, QR vouchers unaffected, no half-written state |

### 9.2 Release gates

| Gate | Condition |
|---|---|
| Every merge | CI green (tests, abuse suite, vectors, static analysis, no `NTAG424_*` in env files, no card `id` in resources) |
| Staging release | Migration rehearsal passed; flags documented |
| Production release | Second-engineer sign-off; rollback plan; release notes for owners where workflows change |
| Pilot go-live | §10 checklist complete |

### 9.3 Hardware matrix (minimum)

| Actions \ devices | 5 Android models (incl. low-end) | 3 iPhones (XS or newer) |
|---|---|---|
| Live authentication (spend) | ✓ | ✓ |
| Bind, replace, register, receive | ✓ | ✓ |
| Station personalisation | 1 designated station phone | — |
| Guest tap (balance page) | ✓ (Chrome) | ✓ (background reading) |
| Card lifted early, retry | ✓ | ✓ |
| Legacy NTAG215 swap | ✓ | ✓ |

### 9.4 Feature flags

| Flag | Default after rollout |
|---|---|
| `v2_phase0_spend_rules` | on (all restaurants) |
| `v2_payments_required` | on |
| `v2_live_auth_required` | on per restaurant once its devices are on app ≥ 2.0 |
| `v2_card_binding`, `v2_legacy_swap` | on for the pilot restaurant first |
| `v2_email_voucher` | on with Phase 8 |
| `v2_station_mode` | platform only |
| `v2_writer_removed` | on one release after P5 |

---

## 10. Pilot go-live checklist

**Security**
- [ ] Phase 0 abuse suite green; zero debits without a presentment in 14 days of production data
- [ ] Penetration test: no open high or critical findings
- [ ] Cryptographic review done; findings closed
- [ ] Production key ceremony done; KCVs recorded; components in two safes; minutes filed
- [ ] HSM IAM: only the crypto service account can use the keys; admin access with two people
- [ ] Append-only triggers, separate DB users, nightly chain verification and off-site anchor running

**Product**
- [ ] Pilot batch accepted (two approvals); delivery received in the restaurant by count + tap
- [ ] App ≥ 2.0 on all pilot devices; minimum version enforced
- [ ] Guest T&C: anonymous card = cash; recovery only with registration (L8)
- [ ] Staff trained: sell, bind, replace, register, receive; "no override" explained

**Operations**
- [ ] Runbooks 1–9 written and the crypto-outage drill done
- [ ] Backups off-site, restore tested this month; 4 GB + swap; health monitoring and alerting
- [ ] Tap domain on 10-year renewal with registrar lock; certificate monitoring
- [ ] Support contact and escalation path for the pilot restaurant

---

## 11. Risks for the implementation

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Premium card supply late (artwork, minimum quantity, lead time) | Medium | Pilot delay | L5 in week 1; lab cards from stock; pilot batch can be small |
| First iOS build, NFC capability or App Review delays | Medium | iPhone features late | L7 early; Android-first pilot is possible without an architecture change |
| Google raw-encryption import procedure harder than expected | Low–Medium | Phase 1 +3–5 days | Staging ceremony in week 4 as a rehearsal |
| Personalisation bugs lock lab cards | Medium | Lost cards, delay | 100 lab cards; deterministic keys; recovery journal (P6-02) |
| Relay latency on weak restaurant networks | Medium | Waiter UX | Measure in P4-04; the Wi-Fi check at onboarding |
| Knowledge concentrated in one engineer (crypto) | Medium | Bus factor | Second-engineer review of every crypto change; external review |
| Legacy balances larger than expected (L1) | Low | Communication, support | Balances are frozen, never lost; swap in Phase 7 |
| Pressure to add features before the pilot | High | Delay | Change control: ADR required; §6 scope is the pilot scope |

---

## 12. Change control during implementation

- **Allowed without an ADR:** bug fixes, performance work, UI copy, test additions, operational tooling, and anything the architecture already specifies.
- **Needs an ADR** (architecture §20):
  - a new table or column not in the architecture;
  - a changed state or transition;
  - a new way to spend, bind or identify a voucher;
  - any change to keys, the crypto service's operations or trust boundaries;
  - any relaxed limit or rule.
- The plan's phase content can be re-ordered without an ADR. Its scope cannot be extended.

---

## 13. Decisions needed from the product owner

1. **L1 result and the message** to restaurants and guests about frozen NTAG21x balances.
2. **Launch date:** confirm that 3 November 2026 would be a digital-voucher launch (§1.1), or move the launch to the pilot date with premium cards (≈ week 17).
3. **Supplier and pilot restaurant** (L5, L10).
4. **Three key custodians** (L3).
5. **Legal opinion** commissioned (L8).
6. **Apple Developer account** (L7).
7. **Payment provider** (L9, needed only for Phase 10).
