# GiftCard Pro v2: production architecture (frozen)

| | |
|---|---|
| **Status** | **FROZEN**, v2.0, 28 September 2026. This is the baseline for implementation. |
| **Change control** | After freezing, a change needs a short **architecture decision record** (ADR) appended to §20: what changes, why, the security impact, and approval by the product owner. The code must not diverge silently from this document. |
| **Supersedes** | The v2 draft (commit `301c551`). For **scope**, it also supersedes `ntag424-platform-architecture.md`, which remains the reference for cryptographic detail (key derivation, APDU sequences, personalisation steps) where §9 and §10 point to it. |
| **Evidence marks** | **[Code]** repository path:line (code at commit `0493784`, unchanged since); **[Vendor]** official documentation; **[Law]** statute or ruling (not legal advice); **[Assessment]** engineering judgement |

---

## 1. Final product decisions

**From the v2 decision** (numbers kept, because §3 refers to them):

1. **NTAG 424 DNA** for every new physical card. NTAG213/215/216 only for cards already in circulation.
2. **Premium PVC cards** with restaurant branding, GiftCard Pro branding and the chip. **Nothing else is visible:** no QR, voucher number, card number, barcode, identifier or secret.
3. **Voucher ≠ presentation medium ≠ physical card.** The voucher owns balance, ledger, expiry, customer and transactions.
4. **Several media per voucher,** all on the same voucher and ledger. Using one is reflected in all.
5. **Cards are inventory:** personalised, cryptographically prepared, tested and worth nothing until bound.
6. **Restaurants never personalise cards,** never generate keys and never know card secrets.
7. **Manager app:** payment → voucher → tap a factory card → bind → active. The phone only relays APDUs.
8. **The backend is the source of truth.** The app is never trusted; every critical operation is authorised by the server.
9. **The chip holds the minimum:** no balance, amount, restaurant, customer, expiry or static identifier.
10. **Online sales:** e-mail voucher at once; a physical card can be bound later to the same voucher. No transfer, no duplicate.
11. **A lost card** = revoke one medium, bind another. The voucher and its ledger never change.
12. Review before implementation.

**Final decisions (this revision):**

13. **Anonymous cards are supported and behave like cash.** Registration is optional and exists only for guests who want recovery. It is never forced.
14. **Printable QR vouchers exist only for digital vouchers:** online purchases, or guests who explicitly choose a printable voucher. They are never part of a physical card.
15. **Apple Wallet and Google Wallet are out of the current scope.** The model stays open for them (§18), but nothing is designed around them.
16. **Every physical card always has a lifecycle state** (§7).
17. **Batch management** with production, key, assignment and delivery data, and live counts per state (§8).
18. **Security has priority over convenience:**
    - backend as source of truth;
    - server-side authorisation;
    - zero secrets on phones;
    - cryptographic verification;
    - tamper-evident audit logs;
    - hardware-backed keys;
    - fraud prevention;
    - least privilege;
    - defence in depth.
19. **Realistic implementation:** no enterprise feature without clear security or operational value.
20. **After this review, the architecture is frozen.**

---

## 2. Architecture at a glance

```mermaid
flowchart LR
    subgraph Guest
        C["Premium card<br/>NTAG 424 DNA<br/>(nothing printed)"]
        E["E-mail voucher<br/>(link + rotating QR)"]
        P["Printable QR<br/>(digital vouchers only)"]
    end
    subgraph Restaurant
        APP["GiftCard Waiter app<br/>Android + iPhone<br/>relay only, no secrets"]
        DB1["Dashboard"]
    end
    subgraph Platform["GiftCard Pro platform (Coolify)"]
        API["Laravel API<br/>vouchers · media · cards · batches<br/>ledger · presentments · audit"]
        SQL[("MySQL")]
        CS["Crypto service<br/>(own container, no DB)"]
    end
    HSM[("Google Cloud HSM<br/>root keys, non-extractable")]
    PSP["Payment provider<br/>(restaurant = merchant)"]
    C <-- "APDU relay" --> APP
    E -- "QR scan" --> APP
    P -- "QR scan" --> APP
    APP -- "TLS, device token" --> API
    DB1 --> API
    API --> SQL
    API -- "mTLS, narrow operations" --> CS
    CS --> HSM
    PSP -- "signed webhooks" --> API
```

**In one paragraph.**
- **A voucher** is money held on the server.
- **Guests reach it through media:** a premium NTAG 424 card, an e-mail voucher, or, for digital vouchers only, a printable QR.
- **A physical card** is an inventory item with a lifecycle from manufacturing to destruction. It belongs to a batch that is made for one restaurant.
- **Setup is central:** cards are personalised with per-card keys derived in an HSM, tested, and shipped with no value.
- **At the till:**
  - a manager binds a card to a paid voucher with one tap;
  - a waiter redeems with one tap;
  - in both cases the phone passes a **server-chosen challenge** to the chip and the answer back, so a copy of anything the card ever sent is useless;
  - every debit consumes a single-use proof of presence.
- **Everything is recorded** in an append-only, hash-chained ledger and audit trail.

**Changed since the v2 draft:**
- wallets removed;
- printable QR limited to digital vouchers;
- anonymous cards as cash;
- card lifecycle and batch management added;
- simplifications adopted in §4.3:
  - no double-entry ledger or organisations yet;
  - one HSM provider;
  - station mode inside the existing app;
  - no card reuse;
  - no self-registration by the guest's own phone;
  - one limit model instead of a limit matrix;
  - no transactional outbox;
  - no balance transfers between vouchers.

---

## 3. Review of the current implementation

All findings are from the code at commit `0493784`.

### 3.1 What already matches

| v2 principle | Current implementation | Evidence |
|---|---|---|
| Backend is the source of truth for money | Amounts, balances, limits and status are decided server-side. Redeem, reload and transfer require an idempotency key (unique per restaurant) and lock the card row. Issuing accepts one optionally. | `GiftCardService.php` (`idempotent()`, `lock()` l.762); `routes/api.php:73` (`idempotent:optional`), `:78` (`idempotent`) |
| The voucher owns balance, ledger, expiry, customer | The balance, totals, expiry, customer and transaction ledger all hang off one row, and the ledger is append-style with before/after balances. **Right data, wrong row:** that row is also the card (§3.2). | `…000004_create_gift_card_tables.php:13–76` |
| NTAG 424 SUN verification | AES-CMAC and SUN MAC per AN12196, and a counter compare-and-set that is replay-safe under concurrency. | `Ntag424SunVerifier.php`, `AesCmac.php`, `CardScanService.php:134–139` |
| One chip, one live voucher | A unique index on the active UID (a virtual column) prevents a chip from being on two usable cards. | `…add_nfc_programming.php` (`nfc_uid_active`) |
| Server-authorised manager flow | S20 is gated by server-issued abilities (`cards.create` + `cards.write_nfc`). Waiters never get it. The app only shows it when the profile allows it. | `DeviceTokenService`, `EnforceDeviceToken`, `WaiterAppIssuingTest` (6 tests) |
| Retry-safe creation from the phone | S20 repeats the same idempotency key after an uncertain answer, so a voucher is never sold twice. | `issue_controller.dart:179`, `issue_controller_test.dart` |
| E-mail pipeline | Templated, queued, per-locale customer e-mails (issued, reloaded, low balance, expiring) with no QR and no attachment. **The content does not match v2:** see C13. | `CardNotificationService.php:48–64`, `QueueCardNotifications`, `TemplatedMail` |
| Guest balance page | `GET /public/cards/{token}` plus the dashboard page `/c/[token]`. The restaurant can switch it off. | `PublicCardController.php`, `dashboard/src/app/c/[token]/page.tsx` |
| Chip reading on both platforms | Android and iPhone read NDEF URL + UID. The iPhone `Info.plist` already declares the NTAG 424 AID for ISO 7816 sessions. | `WaiterNfc.kt:283`, `WaiterNfc.swift:192`, `Info.plist:86–88` |
| Tenant isolation, device-bound tokens, audit | In place and tested. | `TenantIsolationTest`, `bind_access_tokens_to_devices` migration, `audit_logs` |

### 3.2 What must change

| # | Today | v2 requirement it breaks | Change |
|---|---|---|---|
| C1 | **Card = voucher.** `gift_cards` holds balance *and* `public_token`, `card_number`, `nfc_uid`, `nfc_tag_type`, counters and lock flags. | 3, 4, 11 | Voucher keeps money, expiry and customer. New tables `media`, `cards` (physical cards with a lifecycle), `card_batches`, `card_events` (§5, §14). |
| C2 | **Vouchers are active on creation** (`activate` defaults to `true`) and there is **no payment record** of any kind. | 5, 6, 10 | Voucher `pending_payment` → payment recorded (cash, terminal, online) → bound (if a card is sold) → `active`. |
| C3 | **Binding trusts the client.** `method: web_nfc` passes UID, read-back UID and URL as *claims*. Any other method (`manual`, `provisioned`, `printed`) binds **without any verification**. A 424 card "marked as provisioned" gets its UID on the first tap. | 7, 8 | Binding requires a server-verified tap of a personalised stock chip (live AES authentication through the phone). No other binding path exists. |
| C4 | **Spending needs no card.** Redeem, reload and transfer take a card id. `qr`, `manual` and `api` scans skip chip checks, and waiters can spend by typing the number. | 8, and the purpose of 424 | Every debit references a single-use, server-issued presentment. Manual lookup is gone; a manager override with step-up replaces it. |
| C5 | **Card numbers everywhere:** generated (16-digit Luhn, restaurant prefix), shown, printed, exported, used for search, manual entry and transfers. | 2 | No number on any card. A **voucher reference** (non-secret, not a credential) exists on receipts, e-mails and in the dashboard only. |
| C6 | **Print page with QR and full card number.** `GET /cards/{id}/qr` returns the tag URL as an SVG. | 2 | Removed. The printable QR voucher is a separate, revocable medium with its own secret, only for digital vouchers (§6). |
| C7 | **Replace = new card + balance transfer** (new token, new number, `TransferOut`/`TransferIn`). | 11 | Revoke medium + bind medium. The ledger is untouched. |
| C8 | **One URL for everything:** the tag URL, the QR and the e-mail link are the same bearer token (`/c/{uuid}`), stored in clear. | 4, 9 | Separate credentials per medium, stored as hashes. The e-mail link is view-and-show-QR, not a bearer spend link. The chip carries a SUN URL with no static token. |
| C9 | **424 keys in `.env`**, one global pair, HMAC diversification, no key version. | 6, 8 | Crypto service + HSM, NXP AN10922, key sets (§9). |
| C10 | **Default expiry 36 months.** Unlawful for paid vouchers in Austria (audit blocker 1). | 3 (the voucher owns expiry) | The default is no expiry. Expiry is a legal parameter (§5.2). |
| C11 | **No online sales, no payment provider.** | 10 | New: checkout, payment webhooks, e-mail voucher v2 (§6, §11.3). |
| C12 | **The iPhone app cannot write**, so the manager flow is Android-only (`s05_ready.dart:585`). | 7 | Binding needs only APDU relay, which iOS supports. The manager flow works on both (§12). |
| C13 | **Customer e-mails print the balance and the bearer link.** Every template contains `{{ balance }}`, and `balance_url` is the `/c/{public_token}` spend link. | 4, §13.2 invariant 5 | Templates rewritten: no amounts, only the e-mail voucher link (Phase 8, including the expiry-reminder command). (`NotificationTemplateSeeder.php:18–48`, `CardNotificationService.php:51–52`, `CardUrlBuilder.php:19–24`) |

### 3.3 What becomes simpler

| Area | Today | v2 |
|---|---|---|
| Restaurant onboarding | Needs Chrome on Android for Web NFC; blank tags of the right type; explanation of locking | Receive a box of branded cards. Nothing to configure. |
| Selling a card (manager) | Create → hold still while writing → read back → verify → lock (optional) → handle 20+ error codes (wrong type, too small, locked, swapped, URL mismatch, …) | Payment → amount → one tap → done. A handful of errors: "not a card from your stock", "hold longer", "no connection". |
| Programming station | Dashboard page (686 lines) that walks a stack of blank tags against unprogrammed cards | None in restaurants. Personalisation is central. |
| Lost card | Replace creates a new card number and moves money | Revoke and bind; the guest keeps the same voucher. |
| Tag types | ntag213/215/216/424/`qr_only`, capacity probing | One chip type for new cards; legacy types only on read. |
| iPhone | Reader only; managers need Android | Same features on both platforms. |
| Support | "Which number is on the card?", "tag won't write", "tag locked by mistake" | "Tap the card." |
| Testing | Writer matrix per chip type × browser × app × lock state | Relay protocol tests with NXP vectors; one chip type. |

### 3.4 Code that can be removed

Line counts from `wc -l`, including tests. "Remove" means: delete once v2 binding is live and legacy NTAG21x cards no longer need to be *written*. They are still *read* until the end of their sunset.

| Component | Files | Lines |
|---|---|---|
| **Backend: writer and binding workflow** | `NfcProgrammingService.php` (457); `BindNfcTagRequest`, `CheckNfcTagRequest`, `LockNfcTagRequest`, `ReportNfcFailureRequest`; `NfcWriteAttemptResource`; `NfcWriteAttempt` model; enums `NfcWriteMethod`, `NfcWriteStage`, `NfcWriteResult`; `tests/Feature/NfcProgrammingTest.php` (26 tests); the migrations stay (history) | ≈ 1 450 |
| Backend: in `GiftCardService` | `bindNfcTag`, `markNfcLocked`, `assertChipAvailable`, `replace` (l.367–431, 592–695) | ≈ 170 |
| Backend: card numbers and QR | `CardNumberGenerator` (49), `QrCodeService` (21, **kept**: it renders the printable QR), `qr` and `nfcPayload` actions, `card_number_prefix` setting | ≈ 120 |
| **Dashboard: writer and station** | `lib/nfc-programming.ts` (601) + tests (526); `nfc-writer.tsx`, `nfc-program-steps.tsx`, `nfc-attempts.tsx`, `nfc-error.tsx`, `card-qr.tsx`; `hooks/use-nfc-programmer.ts`; `cards/program/page.tsx` (686); `print/cards/[id]/page.tsx`; and at the repository root `e2e/nfc-programming.mjs` (437) | ≈ 2 900 |
| Dashboard: card numbers | Manual entry in the web terminal, transfer by number, number columns, search | ≈ 150 (edits) |
| **Waiter app: writer** | `core/issue/card_programmer.dart` (330) + tests (211); `core/platform/tag_writer.dart` (115); writer paths in `WaiterNfc.kt` (`onWriterTag`, `inspect`, `writeUrl`, `readFresh`, `lock`: l.300–420); writer events in `nfc_service.dart` | ≈ 800 |
| Waiter app: manual number entry | `s11_manual_entry.dart` (459) + its test (330), `components/card_number_field.dart` (289); replaced by a smaller manager override screen. `core/format/card_number.dart` **stays**: it formats the reference of existing vouchers. | ≈ 1 080 |
| **Total** | | **≈ 6 700 lines**, of which about 2 100 are tests and the end-to-end script |

**Kept and reused:**
- the S20 screen shell, amount pad, e-mail field and the idempotent create logic (`issue_controller.dart`);
- `AesCmac`, `Ntag424SunVerifier` (extended with key sets);
- the legacy UID path of `CardScanService` (for NTAG21x reads during the sunset);
- the e-mail pipeline;
- the public balance page (moved to the tap domain).

### 3.5 Technical debt that disappears

1. **Two binding paths**, one of which (`bindUnverified`) binds without any check (`GiftCardActionController.php:147–160`, `NfcProgrammingService.php:231–250`).
2. **"Verified" that is not verified.** Today's read-back is reported by the client. The server cannot tell a real read-back from a forged request.
3. **Chip-size detection by probe writes** in the dashboard (`nfc-programming.ts:309–352`) and by GET_VERSION in the app. There are two implementations of the same heuristic.
4. **`qr_only` as a tag type** (`NfcTagType`): a medium modelled as a chip.
5. **NFC state on the voucher row**: `nfc_tag_type`, `nfc_uid`, `nfc_uid_active` (virtual column with a unique index), `nfc_written_at`, `nfc_verified_at`, `nfc_locked`, `nfc_read_counter`.
6. **Restaurant settings that only exist because restaurants write tags:** `lock_nfc_tags_after_write`, `enforce_nfc_uid_binding`, `card_number_prefix`.
7. **`replaced_by_id` / `replaces_id` chains** and the transfer-based replacement, with their audit special cases.
8. **The waiter app sends `method: web_nfc` from native code**, a compromise made to reuse the dashboard's verified path.
9. **Keys in `.env`** and the `giftcard:nfc-keys` generator command.
10. **The Chrome-on-Android dependency** for programming, and the missing iPhone writer.
11. **The 36-month default expiry** (a legal liability, not only debt).

### 3.6 Security improvements

| Risk today | v2 |
|---|---|
| A photo of the card (QR or number) is enough to spend | The card shows nothing. Its URL changes on every tap. Spending needs a live answer from the chip to a server challenge. |
| Spending without any card (card id, number, `method: qr/api`) | Every debit needs a server-issued, single-use presentment, consumed in the same database transaction. |
| Bindings based on client claims | Binding needs a genuine, personalised chip from this restaurant's stock, proven by AES authentication that the phone cannot fake. |
| A stolen box of blank tags or pre-written cards | A box of cards is worth nothing. Binding needs a manager of that restaurant with step-up, and a lost box is blocked centrally. |
| One leaked token = tag, QR and e-mail compromised | Separate, hashed credentials per medium; each can be revoked on its own. |
| Keys in `.env` (any server compromise = every 424 card) | Root keys in an HSM, per-card derived keys, a crypto service with no key export. A server compromise cannot clone cards. |
| Anyone can overwrite an unlocked NTAG21x | NTAG 424 NDEF is writable only with the card's own K0. |
| Guest e-mail link = spending credential | The e-mail link opens the voucher page. Spending (digital vouchers only) needs a rotating QR on a device confirmed by an e-mail code. |

---

## 4. Final review

### 4.1 Six perspectives

| Perspective | Verdict | Findings and actions |
|---|---|---|
| **Scalability** | ✅ Sufficient for years of growth without redesign | **Volume.** 1 000 restaurants × 2 000 vouchers/year = 2 M vouchers and roughly 10 M transactions/year: ordinary for MySQL with the planned indexes **[Assessment]**. **HSM.** Google Cloud HSM allows 500 symmetric requests per second per region by default **[Vendor]**. One tap needs about 6–8 HSM operations (derivations and MAC), so the quota covers about 60 taps per second platform-wide, far above restaurant peaks. **Bottleneck today** is the 2 GB single server (audit). Vertical scaling plus a read replica for reports is enough; no sharding or microservices are needed. **Batches** of thousands of cards change state in bulk inside one transaction per batch, with no per-card jobs. |
| **Maintainability** | ✅ After the simplifications in §4.3 | **One monolith** (Laravel) plus one small crypto service. One app for waiters, managers and personalisation stations. One HSM provider. One chip type for new cards. The existing ledger code, proven under concurrency in the audit, is kept rather than rewritten. The APDU relay is written once and shared by the till, binding and the station. |
| **Operational simplicity** | ⚠ Acceptable, with four routines that must exist | 1. **Key ceremony:** once, then yearly or when a custodian leaves. 2. **Batch acceptance** per delivery. 3. **Crypto-service monitoring**: two instances, alerting, and the outage runbook (card transactions pause; §10.3). 4. **The tap domain** registered for 10 years with registrar lock and certificate monitoring: if `t.giftcardpro.at` ever lapses, every card in circulation stops working. Runbooks in §19. Nothing else needs daily attention. |
| **Security** | ✅ Meets decision 18 | See §13, which maps every principle to concrete controls. Remaining accepted risks are listed there: relay attack, a compromised backend while in control, owner-level fraud, anonymous cards as cash. |
| **Restaurant workflow** | ✅ Simpler than today | **Sale:** payment → amount → one tap. **Redeem:** one tap → amount. **Lost card** (registered): the guest's recovery code, or a reference search plus the contact's e-mail confirmation → tap a new card. **Stock:** confirm a delivery once. There is no programming, writing, locking or tag-type knowledge, and no Chrome-on-Android requirement. iPhone and Android behave the same. |
| **Future extensibility** | ✅ Additive only | Wallets = new medium types. Chains = an `organization_id` column plus acceptance rules. Double-entry = a migration from the append-only ledger. Offline terminals = a new verifier with SAM AV3. All of these are **additive migrations**: new tables or new nullable columns, with no change to how vouchers, cards, batches or media work (§18). |

### 4.2 Remaining decisions challenged

Each decision was re-examined against "simplify only without reducing security".

| # | Decision | Challenge | Verdict |
|---|---|---|---|
| R1 | Live AES challenge at every card redemption | Could the passive SUN URL suffice and save one round trip? | **Keep.** A SUN URL can be skimmed from a pocket and replayed once. Only a server-chosen challenge stops that (earlier design A4). The cost is about 0.2–0.5 s per tap. **No degraded mode:** SUN verification needs the same crypto service, and a per-restaurant switch to weaker checks would let one restaurant lower security. An outage pauses card transactions; registered guests can use the override (§10.5). |
| R2 | A separate crypto service | Laravel could call the HSM directly. | **Keep, as a sidecar container** on the same host with its own credentials. Direct calls would put HSM credentials in the web app, where any code-injection bug can use them freely. The sidecar gives a narrow API, rate limits and a separate audit trail for about 800 lines of code **[Assessment]**. |
| R3 | HSM tiers T1/T2/T3 | Three tiers is enterprise complexity. | **Simplify: one tier.** Google Cloud HSM (roots non-extractable, per-card keys only briefly in the crypto service's memory). It works from the current hosting and costs a few euros per month **[Vendor]**. The T3 (all-in-HSM) option is removed from the roadmap. |
| R4 | Two-level key derivation (root → batch → card) | Is the batch level needed? | **Keep.** It is cheap and limits a future manufacturer leak to one batch. It also allows manufacturer personalisation later without exposing roots. |
| R5 | SDM meta-read key (K1) per key set, one key set per manufacturer | — | **Keep.** A K1 leak affects privacy, not authenticity. |
| R6 | Double-entry ledger, per-organisation hash chain | Needed for chains, not for single-restaurant vouchers. | **Defer.** Keep today's per-voucher ledger (balance before/after, row locks, idempotency). Make it **append-only** (triggers, no UPDATE/DELETE grant), add a **hash chain** and a **unique presentment id**. Tamper evidence is kept, and 14–20 days are saved. |
| R7 | Organisations, programs, acceptance networks | No chain customer yet. | **Defer.** The restaurant stays the tenant. Adding `organization_id` later is additive (§18). |
| R8 | Presentments (single-use proof of presence) | — | **Keep.** This is what closes every "spend without the card" path. It is one table and one service. |
| R9 | Assurance-level limit matrix (per level: per transaction, per day, lifetime, rolling 30 days) | Complex to explain and to configure. | **Simplify.** Card vouchers no longer carry weak media (R10, R13), so a matrix is not needed. **One limit model** (§6.3): a per-transaction and a per-voucher daily ceiling for all media, plus a few fixed caps for specific risks: legacy cards, the first 24 h of online vouchers, 72 h after a recovery, and overrides. |
| R10 | E-mail voucher on card vouchers: view by default, "enable phone payment" at the counter | An extra role and an extra flow. | **Simplify.** On a card voucher, the e-mail is a **recovery contact** (balance, receipts, recovery). It never spends, so there is no "enable" flow. On a digital voucher, the e-mail voucher spends (rotating QR after device confirmation). |
| R11 | Self-registration by tapping one's own card | Skimming makes it abusable; it only ever gave view rights. | **Remove.** Registration happens at the sale or later at the counter: a manager taps the card (A3), enters the e-mail, and the guest confirms by e-mail link. Tapping with one's own phone still shows the balance. |
| R12 | Card reuse and re-keying of returned cards | A rare case that needs a re-keying flow. | **Remove.** Each card serves one voucher for its life. Returned or replaced cards are **destroyed**. |
| R13 | Printable QR with its own lifetime cap | Decision 14 limits it to digital vouchers. | **Simplify.** It is a bearer voucher by the guest's choice, like the anonymous card. The general limits apply, and a registered contact (if any) is notified of each redemption. There is only one active printable QR per voucher. Re-issuing needs the guest's `select` presentment (for example the e-mail QR or an `email_link`) and kills the old one. It is **revoked automatically when a physical card is bound, and can never be issued on a voucher that has a card**, so card vouchers stay card-strength. |
| R14 | Key set v0 for 424 cards personalised with external tools | Only needed if such cards exist. | **Conditional.** Count them in production. If there are none, do not build the v0 path. |
| R15 | Device attestation (Play Integrity / App Attest) | Phones hold no secrets, and the server verifies all card cryptography. | **Defer.** A modified app can only do what its user's permissions allow, and those are enforced server-side. Revisit if abuse is observed. **Keep certificate pinning** to the ISRG roots (cheap, low risk). |
| R16 | Four-eyes approval | — | **Keep, narrowly:** sales above €300 (adjustable), and recovery of a voucher sold by the same user within 30 days (§11.6). |
| R17 | Risk engine as a subsystem | — | **Simplify:** about eight synchronous rules in the services plus a nightly report (§13.4). No separate engine. |
| R18 | Transactional outbox for media updates | Existed for wallet pushes. | **Remove.** Without wallets, e-mails are queued jobs dispatched after commit. |
| R19 | Personalisation station as a separate app, including a PC/SC desktop reader | Two more clients to maintain. | **Simplify:** a **station mode inside the existing app**, available only to platform admins on an enrolled station phone. It reuses the relay code. Manufacturer manifest import is added when the first manufacturer batch is ordered. |
| R20 | Generic GiftCard Pro-branded stock | Stock ownership per chip or shipment. | **Remove.** Every batch is made for one restaurant (decision 17). |
| R21 | Stored per-batch counters | They can drift. | **Computed.** Counts come from `cards` grouped by state, indexed (§8.3). |
| R22 | Maximum voucher value | Anonymous cash-like cards invite misuse. | **Add a ceiling** (default €500 per voucher, adjustable by the platform) **[Assessment; confirm with counsel]**. |
| R23 | Hash-chained audit log with a daily anchor | — | **Keep.** Cheap, and explicitly required. |
| R24 | Application-level encryption of customer PII | — | **Keep** for e-mail and name, with a blind index for e-mail search. Laravel encrypted casts, keyed from the environment's application key, not from the HSM. |
| R25 | Balance transfers between vouchers | Replacement no longer needs them, and a transfer is a debit that is easy to misuse. | **Remove from v2.** Can be re-added later with presentments on both vouchers. |

### 4.3 Effect of the simplifications

| Removed or deferred | Security impact | Days saved **[Assessment]** |
|---|---|---|
| Double-entry ledger (keep single-entry, append-only, hash-chained) | None for single-restaurant vouchers | 14–20 |
| Organisations and programs | None | 3–4 |
| T3 HSM tier and the CloudHSM spike | Small: per-card keys stay briefly in crypto-service memory, roots do not | 3–5 |
| Wallets and the outbox | None (not in scope) | 10–14 |
| Device attestation | Small (no secrets on phones) | 4–6 |
| Assurance matrix → one limit model | None (no weak media on card vouchers) | 2–3 |
| Self-registration by tap, and "enable phone payment" | Positive (removes an abuse path) | 2–3 |
| Card reuse and re-keying | Positive (fewer states) | 2–3 |
| Separate station app and PC/SC | None | 4–6 |
| **Total** | | **≈ 44–64 engineer-days** |

---

## 5. Domain model

### 5.1 Entities

```mermaid
erDiagram
    RESTAURANT ||--o{ VOUCHER : issues
    RESTAURANT ||--o{ CARD_BATCH : "orders (branded)"
    CUSTOMER |o--o{ VOUCHER : "registered (optional)"
    VOUCHER ||--o{ LEDGER_ENTRY : "append-only, hash-chained"
    VOUCHER ||--o{ MEDIUM : "presented by"
    VOUCHER ||--o{ PAYMENT : "paid by"
    MEDIUM |o--o| CARD : "is (nfc_card)"
    CARD }o--|| CARD_BATCH : "made in"
    CARD ||--o{ CARD_EVENT : "lifecycle history"
    CARD_BATCH }o--|| KEY_SET : "keyed with"
    PRESENTMENT }o--|| MEDIUM : "proves"
    LEDGER_ENTRY |o--o| PRESENTMENT : "consumes (debits)"
```

| Entity | Owns | Never owns |
|---|---|---|
| **Voucher** | Balance, ledger, expiry, status, optional customer, issuing restaurant, reference, payments | Anything about how it is presented |
| **Medium** | "This credential may access that voucher", its status, its secret hash if any | Money, expiry |
| **Card** (physical) | UID, batch, key set, lifecycle state, stock location | Money, customer, expiry |
| **Batch** | Production, key, assignment and delivery data | Money |
| **Presentment** | A single-use, 60-second proof that a medium was presented to this device and user | — |

### 5.2 Voucher rules

- **Reference:** 10 characters of Crockford base32 plus a check character, random, unique per restaurant (e.g. `GC-7K4M-2Q9P-X`).
  - It appears on receipts, e-mails and in the dashboard. It is **never printed on a card and never a credential**: it finds a voucher, it never spends it.
  - Existing vouchers keep their current numbers as their reference.
- **Status:**
  - `pending_payment` → `awaiting_card` (paid, card still to bind) → `active`;
  - `blocked`, `expired`, `cancelled`, `closed`.
  - "Redeemed" is **not a status**: it is an active voucher with balance 0 (a reload reopens it).
- **Anonymous or registered (decision 13):**
  - **Anonymous:** no customer, no contact. Losing the card loses the balance.
  - **Registered:** a confirmed e-mail contact, used for recovery, balance and receipts. Registration is offered and never required.
- **Expiry:** none by default. In Austria vouchers are valid 30 years unless validly limited, and short expiries on paid vouchers have been struck down **[Law]**. Any expiry is a restaurant setting behind a legal warning.
- **Maximum value:** a platform ceiling (default €500 per voucher) and a restaurant setting below it (R22).

---

## 6. Presentation media and spending rules

### 6.1 The media in scope

| Medium | Held by | What it is | Level | Spends |
|---|---|---|---|---|
| `nfc_card` | Guest | Premium NTAG 424 DNA card, nothing printed | **A3**: live AES challenge from the server | Yes |
| `email_voucher`, digital voucher | Recipient | Link to the voucher page. The rotating QR appears after a one-time e-mail code confirms the device. | **A2**: fresh value from a confirmed device | Yes |
| `email_voucher`, card voucher | Registered guest | Recovery contact: balance, receipts, suspend, and a recovery code valid only for `select` | A0 | **No** |
| `printable_qr` | Holder of the paper or PDF | Static QR for **digital vouchers only** (decision 14); one active per voucher | **A1**: bearer | Yes |
| `legacy_token` | Old NTAG21x card, printed QR or old e-mail link | The old `public_token`; one medium for all three places | A1, capped | Yes, until the sunset |
| *future:* `wallet_apple`, `wallet_google` | — | Out of scope (§18) | — | — |

### 6.2 Allowed combinations

| Voucher sold as | Media |
|---|---|
| Card, anonymous (cash sale, no e-mail) | `nfc_card` |
| Card, registered | `nfc_card` + `email_voucher` (recovery contact) |
| Online / digital | `email_voucher` (spends) + optional `printable_qr` |
| Digital that later receives a card (§11.4) | + `nfc_card`. **The printable QR is revoked** at binding; the e-mail voucher keeps spending. |
| Printable voucher sold in person | `printable_qr` (+ optional `email_voucher`) |

### 6.3 One limit model

All limits are restaurant settings, within platform bounds. They are checked in the same transaction as the debit.

| Limit | Default | Applies to |
|---|---|---|
| Maximum voucher value | €500 | Sale and reload |
| Per transaction | €250 | Every debit, all media |
| Per voucher per day | €500 | Sum of all debits of a voucher |
| Legacy media | €50 per transaction, €100 per day | `legacy_token` during the sunset |
| Online, first 24 h after payment | €100 in total, **no card binding** | Online vouchers (stolen-card purchases) |
| New card after recovery without the old card | €100 in total during the first 72 h | Registered vouchers (§11.6) |
| Override (unreadable card) | €50 each; two per voucher per 30 days; five per restaurant per day | Registered vouchers only, contact confirms (§10.5) |

### 6.4 Consistency

There is one ledger, and every medium reads it live: card, e-mail voucher page, app and dashboard. **No medium carries a value:** e-mails contain a link, never an amount; printable QRs show no value; the chip holds nothing. So "using one medium updates all others" is true by construction, and nothing needs synchronising.

---

## 7. Physical card lifecycle

Every card row always has exactly one **stored state**. Transitions happen only through one service (`CardLifecycle`), which checks the guard, writes the new state and appends a `card_events` row in the same transaction. A database check constraint allows only the listed states, and the service allows only the listed transitions.

### 7.1 States

```mermaid
stateDiagram-v2
    direction TB
    [*] --> manufactured: blank chip registered (in-house)
    [*] --> personalized: manufacturer manifest imported
    manufactured --> personalized: station personalisation verified
    manufactured --> qa_failed: personalisation failed twice
    personalized --> qa_passed: per-card test (in-house) / batch accepted (manufacturer)
    personalized --> qa_failed: test failed / batch rejected
    qa_passed --> in_inventory: batch accepted (two approvers)
    in_inventory --> assigned: batch packed for its restaurant
    assigned --> shipped: dispatched
    shipped --> delivered: carrier delivered
    shipped --> lost: shipment lost
    delivered --> available: restaurant receipt (count + tap)
    delivered --> lost: missing at receipt
    available --> bound: manager tap (A3) to a paid voucher
    available --> lost: missing from restaurant stock
    bound --> revoked: refund / batch compromised
    qa_passed --> qa_failed: batch rejected
    bound --> active: voucher activated
    bound --> available: sale cancelled before activation (refunded)
    active --> suspended: contact / manager / risk rule
    suspended --> active: resume (see 7.2)
    active --> replaced: successor card bound
    suspended --> replaced: successor card bound
    active --> revoked: fraud / voucher closed / refunded / owner
    suspended --> revoked
    qa_failed --> destroyed
    lost --> destroyed: written off
    replaced --> destroyed: returned / written off
    revoked --> destroyed: returned / written off
    destroyed --> [*]
```

When a batch is compromised, every card from `in_inventory` to `bound` becomes `revoked` (§8.2). Those arrows are left out of the diagram for readability.

| State | Meaning | Can bind | Can spend |
|---|---|---|---|
| `manufactured` | Blank chip registered at an in-house station (transport keys) | — | — |
| `personalized` | Keys, NDEF template and SDM set; verified as an outsider | — | — |
| `qa_passed` / `qa_failed` | Passed or failed quality testing (a rejected batch fails all its cards) | — | — |
| `in_inventory` | Central stock, batch accepted | — | — |
| `assigned` | Packed for its batch's restaurant, awaiting dispatch | — | — |
| `shipped` | On the way | — | — |
| `delivered` | Arrived; not yet checked in by the restaurant | — | — |
| `available` | In the restaurant's stock, ready to sell | **Yes** | — |
| `bound` | Linked to a paid voucher that is waiting for activation (e.g. four-eyes approval above the threshold) | — | — |
| `active` | Bound, and the voucher is active | — | **Yes** (if the voucher allows) |
| `suspended` | Temporarily blocked | — | — |
| `replaced` | Revoked because a successor card was bound (successor id recorded) | — | — |
| `revoked` | Permanently invalid | — | — |
| `lost` | Missing in transit or from stock; never bindable again | — | — |
| `destroyed` | Physically destroyed or written off | — | — |

**Derived display states:**
- **"Redeemed"** = `active` + voucher balance 0;
- **"Expired"** = `active` + voucher expired;
- **"Blocked"** = `active` + voucher blocked.

These are **not stored on the card**, because the voucher owns balance, expiry and status (decision 3). Storing them twice would create two sources of truth. The dashboard and the app always show the combined state, so every card visibly has one.

**Deliberate choices:**
- **No reuse (R12).** `replaced`, `revoked` and `lost` never return to stock.
- **Only checked-in cards can be sold.** Receipt checks the delivered count (§11.8).

### 7.2 Transitions, guards and actors

| Transition | Guard | Authorised |
|---|---|---|
| → `manufactured` | Genuine NXP chip (originality signature), UID unknown | `station_operator` on an enrolled station phone |
| → `personalized` | Every step verified by the server / signed manifest, no duplicate UID | `station_operator` / two `platform_admin` (import) |
| → `qa_passed` / `qa_failed` | SUN verifies, K3 authenticates, NDEF write refused, settings as profiled (per card in-house; sample per batch for manufacturer batches) | Automatic / two `platform_admin` |
| → `in_inventory` → `assigned` → `shipped` → `delivered` | Batch status changes (§8.2) | `platform_admin` |
| `delivered` → `available` | Receipt: counted quantity and one A3 tap (`purpose = receive`) by a manager of **the batch's restaurant**; per-card taps when on hold (§11.8) | Manager |
| `delivered` → `lost` | Cards still missing after the platform's investigation of an `on_hold` batch | `platform_admin` |
| `available` → `bound` | A3 presentment (`purpose = bind`); card's restaurant = voucher's restaurant; voucher paid (`awaiting_card`) or `active` | Manager (`cards.bind`) |
| `bound` → `active` | Voucher activation (payment recorded, approval given where needed) | System, same transaction |
| `bound` → `available` | Sale cancelled before activation; payment refunded; no debit exists | Owner |
| `active` → `suspended` | Reason required | Contact (from the voucher page, confirmed by e-mail link), manager, or risk rule |
| `suspended` → `active` | Suspended by the **contact** → the contact confirms by e-mail link. Suspended by a **manager** → manager A3 tap + step-up. Suspended by a **risk rule** → owner + A3 tap. | As stated |
| → `replaced` | Recovery or replacement rules (§11.6); successor bound in the same transaction | Manager + step-up (+ owner where §11.6 says) |
| → `revoked` | Reason: fraud, voucher closed, refund, compromised batch, dead chip on request | Owner, or system (refund, compromise playbook) |
| `available` → `lost` | Stock count shows the card missing | Owner |
| → `destroyed` | Only from `qa_failed`, `lost`, `replaced` or `revoked` | `platform_admin`, or owner for returned cards |

**Platform roles** (least privilege):
- `platform_admin`: batches, shipments, key-set metadata, approvals; **never** vouchers or money;
- `station_operator`: station mode on enrolled station phones only;
- `key_custodian`: key ceremonies only.

No person holds both `station_operator` and batch-approval rights for the same batch.

Every transition is written to `card_events`: from state, to state, reason, actor, device, request id, and the consumed presentment where there is one. `card_events` is append-only and part of the hash-chained audit trail.

---

## 8. Batch management

### 8.1 What a batch is

**One batch = one restaurant order = one print run = one shipment.** This is a simplification (R20): no partial shipments, no shared stock. A restaurant's reorder is a new batch.

| Field | Content |
|---|---|
| `id`, `batch_code` | Internal id and a human code (`B-2026-0007`). **Never on the card or in its URL.** |
| `restaurant_id` | The assigned restaurant (branded cards) |
| `manufacturer` | Card supplier / personaliser |
| `chip_type` | `ntag424_dna` |
| `card_design_ref` | Artwork version printed on the cards |
| `quantity_ordered`, `quantity_registered` (computed) | Ordered vs cards actually registered for the batch (manifest or station) |
| `key_set_version` | Keys used (one key set per manufacturer, R5) |
| `personalization` | `in_house_station` or `manufacturer` |
| `production_date` | From the supplier |
| `ordered_at`, `personalized_at`, `accepted_at`, `shipped_at`, `delivered_at`, `received_at` | Lifecycle dates |
| `accepted_by`, `accepted_second_by` | Two approvers |
| `received_by` | Restaurant manager who confirmed |
| `tracking_ref` | Carrier reference |
| `manifest_sha256` | Signed manufacturer manifest (UID, originality signature, initial counter, key version per card) |
| `qa_report` | Sample results, failures |
| `status` | See §8.2 |

### 8.2 Batch status

```mermaid
stateDiagram-v2
    direction TB
    [*] --> ordered
    ordered --> in_production
    in_production --> personalized
    personalized --> qa_testing
    qa_testing --> accepted: 2 approvals
    qa_testing --> rejected: any failure
    accepted --> assigned: packed
    assigned --> shipped
    shipped --> delivered
    shipped --> lost: shipment lost
    delivered --> in_service: receipt confirmed
    delivered --> on_hold: count mismatch
    on_hold --> in_service: missing cards marked lost
    in_service --> depleted: no card left available
    in_service --> compromised: key leak
    depleted --> in_service: a cancelled sale returns a card
    depleted --> closed: all cards terminal
    compromised --> closed: all cards terminal
    rejected --> closed: cards destroyed
    lost --> closed: cards destroyed
    closed --> [*]
```

`compromised` can be set from any status from `accepted` onwards; the diagram shows only the most common path. **Terminal card states** are `lost`, `replaced`, `revoked` and `destroyed`.

A batch status change moves all its cards in one transaction and writes their `card_events` in bulk:
- `accepted` → cards `in_inventory`;
- `assigned` → `assigned`;
- `shipped` → `shipped`;
- `rejected` → `qa_failed`;
- `lost` → `lost`;
- `compromised` → every card not yet with a guest (`in_inventory` to `bound`) `revoked`; `active` and `suspended` cards limited to possession proof and swap (§8.4).

### 8.3 Counts, always current

Counts are **computed**, not stored (R21): an indexed `GROUP BY batch_id, state` over `cards`, exposed as a view.

| Bucket | States |
|---|---|
| In production / QA | `manufactured`, `personalized` |
| QA failed | `qa_failed` |
| In stock (central) | `qa_passed`, `in_inventory`, `assigned` |
| In transit | `shipped`, `delivered` |
| **In stock (restaurant)** | `available` |
| **Activated** | `bound`, `active`, `suspended` (with "redeemed" shown separately) |
| **Replaced** | `replaced` |
| **Revoked** | `revoked` |
| Lost | `lost` |
| **Destroyed** | `destroyed` |

- **Reconciliation invariant:** the sum of all buckets equals the number of cards registered for the batch (`quantity_registered`). Registered compared with `quantity_ordered` shows any production shortfall. A nightly check alerts on any difference.
- **Platform admin:** all batches, per supplier, per restaurant.
- **Owner or manager:** their batches and their `available` count.
- **Low-stock alert** when `available` drops below a threshold (default 20). It offers "Order more cards", which creates a batch in `ordered` for the platform to confirm. Commercial terms are handled outside the system.

### 8.4 Batch-level security

- **Acceptance:** the sample test and two approvals are needed before any card leaves central stock (earlier design §8.4).
- **Compromise playbook:** batch → `compromised`.
  - Its `active` cards can still be tapped to **prove possession**, but they cannot spend.
  - The manager app offers an immediate swap to a new card (§11.6), and registered guests are invited.
  - Its `available` cards are revoked.
- **Lost shipment:** its cards go to `lost`, which is final.

---

## 9. Chip content and cryptography

The details (APDU sequences, file settings, derivation input layouts, ceremony script) are in `ntag424-platform-architecture.md` §6 and §8. This section is the binding summary, including the v2 changes.

### 9.1 What the card carries

| Printed | On the chip |
|---|---|
| Restaurant branding, GiftCard Pro branding. Nothing else. | NDEF URL `https://t.giftcardpro.at/{k}?e=<32 hex>&m=<16 hex>`. `{k}` = key-set version, shared by every card of that key set. `e` = UID + tap counter, encrypted with random padding, different on every tap. `m` = MAC with the card's own key. |
| | Five AES-128 keys, never readable; SDM configuration; NDEF writable only with the card's own K0 |

**Not on the card:** balance, amount, restaurant, customer, expiry, reference, token, batch code, or any value that stays the same between taps.

**Stated limit:** the 7-byte UID is sent in clear in the radio handshake to any NFC reader (ISO 14443). It links to nothing outside our database.

### 9.2 Keys

| Slot | Purpose | Key |
|---|---|---|
| K0 | Change keys and settings (personalisation only) | Per card: AN10922(batch key(root K0)) |
| K1 | Encrypt UID + counter in the URL | **Per key set**, generated in the ceremony; one key set per manufacturer (R5) |
| K2 | SUN MAC | Per card |
| K3 | Live challenge at the till and at binding; no write rights | Per card |
| K4 | Reserved, set to a random per-card value | Per card |

- **Derivation:** NXP AN10922, two levels (root → batch → card), exactly as specified in the earlier design §6.4. That includes the 32-byte padding with CMAC subkey K2, which is **not** a plain CMAC call. It is verified against NXP's test vectors in CI.
- **No card key is stored anywhere:** keys are recomputed on demand.
- **Not enabled** (irreversible or abusable): LRP, Random ID, read-counter limit, failed-authentication lock-out.

### 9.3 Where keys live

- **Google Cloud HSM** (EU region), one provider (R3).
  - Roots are imported once from a dual-control ceremony. Google's raw AES operations are available for imported keys only **[Vendor]**, which the ceremony provides.
  - They are non-extractable in the HSM afterwards.
- **Crypto service:** a separate container with its own credentials and no database. It offers only:
  - `sun.verify`
  - `auth.begin` / `auth.finish` (challenge stays inside)
  - `perso.*` (station identity only, per approved batch)
  - `export.batch_keys` (ceremony only, two approvals)

  Every call is rate-limited and logged to a sink the web app cannot write.
- **Nowhere else:** not in `.env`, the database, backups, logs, phones or browsers.
- **Rotation:** a new key set per manufacturer, and at least yearly or when a custodian leaves. Old key sets stay `verify_only` while cards use them.
- **Key ceremony:**
  - three named custodians, of whom two must be present;
  - XOR components in two safes;
  - key check values (KCV) recorded;
  - a scripted procedure and minutes (earlier design §6.7).

---

## 10. Verification

### 10.1 Presentments

A presentment is the server's record that **this medium, or this guest, was genuinely presented to this device and user, now.**

**Purposes:**

| Purpose | Required state | Used by |
|---|---|---|
| `spend` | Card `active`; voucher `active` | Redemptions |
| `bind` | Card `available` | Sale, add card, replacement (the new card) |
| `select` | Any medium of an existing voucher; an old card in any non-terminal state | Proves the guest or possession: add a card to an existing voucher, replacement (the old card or the contact), registration, printable re-issue |
| `receive` | Card `delivered` | Delivery check-in |
| `resume` | Card `suspended` | Resume by manager (card tap) or owner; a contact resumes with an `email_link` (§7.2) |
| `verify` | Any state; read-only | Card info |

**Methods:**
- `live_auth`: card, A3;
- `rotating_qr`: A2;
- `printable_qr`: A1;
- `legacy_token`: A1;
- `email_link`: a one-time link sent to a confirmed contact. It counts as `select` for recovery, contact changes and override confirmation, and as `resume` or `suspend` for the contact's own card actions.

**Validity and enforcement:**
- 60 seconds, bound to device, user and restaurant.
- Single use, enforced by an atomic `verified → consumed` update.
- The consuming row stores the presentment id: ledger entry, card event, medium change, receipt. Ledger entries additionally have a **unique** index on it.

### 10.2 Card: live authentication (A3)

1. **Phone → card:** select the application, select file E104, read the NDEF (SUN URL), then `AuthenticateEV2First` with key 3 (part 1). The card answers with E(K3, RndB).
2. **Phone → server:** RF UID, SUN URL and the 16-byte answer.
3. **Crypto service:** verifies the SUN, derives K3 for this UID, draws a random RndA, and returns the part-2 command.
4. **Phone → card → phone → server:** the card's final answer. The card can now be removed.
5. **Server checks, all of them:**
   - authentication succeeded;
   - RF UID = UID in the SUN = registry UID;
   - SUN counter increased (atomic compare-and-set);
   - card state as required by the purpose (§10.1);
   - batch not compromised (otherwise only `select` and `verify` are allowed);
   - device, user and restaurant allowed.

The phone never sees a key or RndA. A recording of any earlier exchange cannot answer a new challenge.

### 10.3 SUN only: the guest's own phone

- A SUN-verified tap on the guest's phone shows the balance page (A0), if the restaurant allows public balance.
- **SUN alone never spends, binds or receives.**
- **There is no degraded mode.** Verifying a SUN needs the crypto service as much as live authentication does, and a restaurant-level switch to weaker checks would let one restaurant lower security.
- **If the crypto service or HSM is down,** card transactions pause. Registered guests can be served through the override (§10.5), which needs no card cryptography, and QR vouchers keep working.
- Availability is handled by running two crypto-service instances and by the HSM provider's service level (§19).
- **The web dashboard never redeems or binds cards,** because Web NFC cannot run the challenge **[Vendor]**.

### 10.4 QR codes

- **Rotating QR** (digital e-mail voucher):
  - an HMAC of the medium seed over a 30-second step, truncated, plus the medium id;
  - the current and previous step are accepted, each step only once;
  - the seed is encrypted with the application key;
  - shown only on devices confirmed by a one-time e-mail code.
- **Recovery code** (registered card vouchers): the same mechanism on the recovery-contact page, valid **only for `select`**, never for spending.
- **Printable QR:** a 256-bit random secret, stored as a SHA-256 hash; one active per voucher.
  - Created with the sale. Re-issuing needs a guest `select` presentment.
  - It is refused on any voucher that has a physical card.
- **Legacy token:** hash lookup of the old `public_token`; legacy limits apply.

### 10.5 Overrides (unreadable card, no silent bypass)

- **Registered vouchers only.** An anonymous voucher cannot be identified without its card (cash semantics). An override on it would let staff drain vouchers nobody watches.
- **Flow:**
  1. The manager finds the voucher by reference or contact.
  2. The contact receives a one-time confirmation link (`email_link` presentment).
  3. The guest confirms at the table.
  4. The manager completes it with step-up (device-bound biometric key or server-verified PIN) and a reason.
- **Limits:** €50 per override, two per voucher per 30 days, five per restaurant per day.
- **Effects:** risk event, owner report; the voucher is flagged "replace card".
- Waiters, API tokens and the dashboard without step-up can never override.

### 10.6 A debit, end to end

In one database transaction:
1. Lock the presentment (or override): valid, unused, same device/user/restaurant, `purpose = spend`, and its medium bound to this voucher.
2. Lock the voucher: `active`; card `active` where applicable; balance; limits (§6.3).
3. Append the ledger entry with the presentment id (unique) and the hash-chain link.
4. Mark the presentment consumed.
5. Commit.

A retry with the same idempotency key returns the original result.

---

## 11. Flows

### 11.1 Sale with a physical card (manager, Android or iPhone)

```mermaid
sequenceDiagram
    autonumber
    actor Mgr as Manager
    participant App as App (relay only)
    participant Card as Available card
    participant API as Backend
    participant CS as Crypto service
    Mgr->>App: amount · payment (cash / terminal) · guest e-mail (optional)
    App->>API: POST /vouchers + Idempotency-Key
    API-->>App: voucher V awaiting_card · payment recorded
    Mgr->>App: hold card
    App->>Card: select, read NDEF, auth part 1 (K3)
    Card-->>App: SUN URL, E(K3, RndB)
    App->>API: POST /presentments {purpose: bind, …}
    API->>CS: sun.verify, auth.begin
    API-->>App: part-2 command
    App->>Card: part 2
    Card-->>App: answer (card may be removed)
    App->>API: POST /presentments/{p}/complete
    API->>CS: auth.finish ✅
    API->>API: card available, same restaurant?
    App->>API: POST /vouchers/V/cards {presentment: p}
    API->>API: card bound → active · voucher active · events · audit
    API-->>App: ✅ 50,00 € on card ••A1
```

- **Anonymous sale:** no e-mail. The success screen shows the reference for the restaurant's own records, and a line reminds staff: "Anonymous card: like cash."
- **Registered sale:** the guest receives a confirmation link. The e-mail becomes a recovery contact once confirmed.
- **Above the four-eyes threshold** (default €300), a second person approves before activation.

### 11.2 Printable voucher sold in person

1. Amount and payment, then "Printable voucher".
2. The voucher gets a `printable_qr` medium. The app shows or prints it (receipt printer or PDF), optionally also by e-mail.
3. No card is involved.

### 11.3 Online sale

```mermaid
sequenceDiagram
    autonumber
    actor Buyer
    participant Shop as Voucher shop (restaurant-branded)
    participant PSP as Payment provider (restaurant account)
    participant API as Backend
    Buyer->>Shop: amount, recipient, message, "printable" (optional)
    Shop->>API: create order
    API->>PSP: checkout, direct charge, 3-D Secure
    PSP->>API: signed webhook: paid
    API->>API: verify signature, account, amount, currency → payment → voucher active
    API->>API: media: e-mail voucher (+ printable QR) · e-mail job after commit
    Note over API: First 24 h: 100 € total, no card binding
```

- **Merchant of record: the restaurant** (Stripe Connect direct charges or Mollie Connect) **[Vendor]**.
- **Refund:** block the voucher → PSP refund → reversal after confirmation.
- **Dispute:** block, then notify the owner.

### 11.4 Physical card for an existing (online) voucher

1. The guest shows the e-mail voucher's rotating QR (A2), or the printable QR.
2. The manager scans it: presentment with `purpose = select`.
3. The manager taps an available card: bind, as in 11.1 steps 4–17. **Both presentments are consumed by the bind** (`POST /vouchers/{id}/cards {bind, select}`).
4. The server revokes the printable QR, if any. A registered contact gets an e-mail: "A card was added to your voucher."

Refused within 24 h of an online payment (§6.3).

### 11.5 Redeem

- **Card:** the waiter taps (A3, steps as in 11.1 but `purpose = spend`) → amount → `POST /vouchers/{id}/redemptions {amount, presentment}`.
- **E-mail voucher or printable QR:** the waiter scans → amount → the same call.
- **Every registered voucher** (card or digital): the confirmed contact is e-mailed a receipt of each redemption.

### 11.6 Lost, damaged or stolen card

| Situation | Rule |
|---|---|
| Damaged, chip still answers | The old card is tapped (`select`), which proves possession. Then a new available card is tapped (`bind`): the old card becomes `replaced`. Immediate, manager step-up, for anonymous and registered cards alike. |
| Lost, stolen or chip dead, **registered** | The guest proves the voucher: either the recovery code from the confirmed contact page (`select`), or the manager searches by reference or contact and the contact confirms via an `email_link`. Then: manager step-up; bind a new card; the old card becomes `replaced`. The new card spends at most €100 in its first 72 h; every contact is notified; risk rule "rebind then debit". If the same user sold the voucher within the last 30 days, the owner (a different person) approves. |
| Lost or stolen, **anonymous** | **Like cash: the balance is lost** (decision 13). There is no recovery path for staff or owners, so social engineering is impossible. |
| Chip dead, **anonymous** | Unidentifiable, so treated like lost. The plastic can be destroyed. Its record stays `active` and harmless, because nobody can present it. |

### 11.7 Registering a card later (at the counter)

1. The guest asks for recovery.
2. A manager taps the card (A3, `purpose = select`, consumed by the registration) and enters the guest's e-mail.
3. The guest confirms via the link, and the contact becomes active.

Changing an existing contact needs confirmation from the old address, or the same card tap plus owner approval. The old address is always notified.

There is no registration from the guest's own phone (R11).

### 11.8 Receiving a delivery

1. The pack arrives. The manager opens "Receive cards", enters the **counted quantity**, and taps any card from the pack (A3, `purpose = receive`).
2. The server checks that the card belongs to a `delivered` batch of this restaurant.
3. **Count equals the batch quantity:** the batch becomes `in_service` and all its cards `available`.
4. **Count differs:** the batch goes `on_hold`, and the manager checks cards in one by one by tapping them. Each tapped card becomes `available`. After the platform's investigation, the untapped cards become `lost`.

A card from any other batch or restaurant is refused. Nothing that has not arrived can ever be sold.

### 11.9 Legacy NTAG21x card

It is read as today and spends within the legacy limits. A manager tap on a new card swaps it: new card `active`, the old legacy card `replaced`, and its legacy medium revoked. The sunset rules are in §16.

---

## 12. Applications

### 12.1 GiftCard Waiter app (Android and iPhone)

| Screen | Role | Replaces |
|---|---|---|
| Redeem (tap card or scan QR) | Waiter, manager | Today's scan; manual number entry removed |
| **Sell voucher**: card, printable, or e-mail only | Manager, owner | S20 create → write → verify → lock |
| **Add card to voucher** | Manager, owner | New |
| **Replace card** | Manager, owner | Dashboard "replace" (money transfer) |
| **Register card** (§11.7) | Manager | New |
| **Receive cards** | Manager | New |
| **Card info**: tap → state, batch, voucher | Manager | New |
| **Override** (registered vouchers, contact confirms) | Manager | Manual entry (S11) |
| **Station mode**: personalise and verify blank chips | `station_operator` on an enrolled station phone only | External NXP tools |

- **The relay** is one native component per platform: Android `IsoDep`, iOS `NFCISO7816Tag` (AID already declared in `Info.plist:86–88` **[Code]**).
  - It opens a session, sends the four fixed commands (select application, select file, read binary, auth part 1), and forwards server commands byte for byte.
  - It keeps nothing.
- **Reused from S20:** the idempotent create controller, the screen shell, the amount pad and the e-mail validation.
- **Deleted:** the writer, GET_VERSION detection, lock and read-back.

### 12.2 Dashboard

- **Vouchers:** by reference; status, balance, history, media (card ••A1 with its lifecycle state, e-mail contact, printable QR), revoke, block.
- **Cards and batches:** stock per batch (the §8.3 buckets), low-stock alert, "order more cards", card history (`card_events`).
- **Online shop settings:** payment-provider onboarding, amounts, texts, refund policy.
- **Owner reports:** overrides, risk events, cash reconciliation (declared cash vs cash sales), four-eyes approvals.
- **Web terminal:** scans e-mail and printable QRs with the camera. **No card handling** (§10.3) and no manual number entry.

### 12.3 Platform admin

Key sets (metadata and KCVs only), batches (create, approve, import manifest, accept, ship, compromise), station devices, and ledger/audit verification results. It requires FIDO2-protected admin logins.

---

## 13. Security architecture

### 13.1 Principles → controls (decision 18)

| Principle | Controls |
|---|---|
| **Backend as source of truth** | Balance, status, limits, card state and media exist only on the server. Clients send intentions and raw bytes, never results. |
| **Server-side authorisation** | Every request is checked for role, ability, tenant and device. Every debit, bind, receive and resume consumes a presentment. Money endpoints are idempotent and row-locked. |
| **Zero secrets on phones** | The app holds a device-bound login token and a step-up key (for proving the user, not the card). No card keys, no challenges, no card data. APDUs are relayed byte for byte. |
| **Cryptographic verification** | AES live challenge (K3) for every card use at the till; SUN MAC and counter; NXP originality signature at personalisation; HMAC for rotating QRs; hashed static secrets. |
| **Tamper-evident audit** | Ledger, `card_events` and `audit_logs` are append-only (triggers, no UPDATE/DELETE grant) and hash-chained. The chain head is anchored nightly off-site (object-lock bucket and owner e-mail). A nightly verifier recomputes balances and chains. |
| **Hardware-backed keys** | Roots in Google Cloud HSM, imported once in a dual-control ceremony; per-card keys derived on demand; crypto service with no key export. |
| **Fraud prevention** | The limit model (§6.3); payment evidence for every sale; four-eyes above a threshold; the override limits; risk rules (§13.4); online velocity rules and 3-D Secure. |
| **Least privilege** | Waiters: scan and redeem only. Managers: sell, bind, replace, override within limits. Owners: approvals and settings. Platform staff: batches and stations, never vouchers. Three database users (app DML without UPDATE/DELETE on append-only tables, migrator, read-only reporting). |
| **Defence in depth** | Chip crypto + presentment + limits + risk rules + audit + reconciliation. Each layer alone limits the damage when another fails. |

### 13.2 Invariants (each with an automated test)

1. **No debit** without a consumed presentment or override, in the same transaction.
2. **No card is bound** unless it is `available`, belongs to the voucher's restaurant, and was proven with A3.
3. **No sale** without a payment record. **No online voucher** without a verified webhook.
4. **No key material** outside the HSM and the crypto service's memory.
5. **No value on any medium,** and nothing identifying printed on a card.
6. **Counters only go up.** Challenges and presentments are single-use and short-lived.
7. **Card state changes only through `CardLifecycle`,** always with an event.
8. **Changing who can use an existing voucher needs the guest.** This covers binding a card to a voucher that existed before this visit, re-issuing a printable QR, and changing the contact. It needs the guest's `select` presentment: the old card, the voucher's QR, the recovery code or an `email_link` to the confirmed contact. Owners cannot replace the guest in this, and anonymous vouchers have no recovery (§11.6). The known contacts are notified.
   - **Exception:** first-time media created within the sale itself (the card bound at the counter, the printable QR of a printable sale) need no guest presentment, because the guest is the buyer standing there.
9. **Append-only tables** are never updated or deleted by the application user.

### 13.3 Threat model (consolidated)

| Threat | Likelihood | Impact | Mitigation | Remaining risk |
|---|---|---|---|---|
| Photo or copy of the card | — | — | Nothing printed; the URL changes per tap and never spends | None |
| Skimming a card in a pocket | Medium | Low | Spending needs the live challenge; a skimmed URL is useless at the till | None: SUN alone never spends |
| Cloned card | Low | Low | Per-card keys (EAL4 chip); live challenge | Laboratory extraction of one card's keys |
| Relay attack (live) | Low | Low–Medium | RF UID check (phone emulation fails), limits, physical-card policy | Hardware relay with a UID-programmable emulator: accepted |
| Lost anonymous card | Medium | Guest loses balance | Cash semantics, clearly communicated at sale | **Accepted by product decision** |
| Stolen box of cards | Medium | None | Zero value; binding only after the restaurant confirms receipt; lost shipments are final | None |
| Waiter spends without the card | Medium today | Medium | Presentment required; no manual lookup | None (overrides are manager-only) |
| Manager sells without payment | Medium | Medium–High | Payment record; cash reconciliation; four-eyes > €300; owner report | Owner-level fraud |
| Manager binds a card to someone else's voucher | Low | Medium | Invariant 8; guest notification; 72 h cap after recovery | Collusion with an owner |
| Leaked printable QR | Medium | Low–Medium | Guest's choice (bearer); limits; redemption notices; re-issue; revoked when a card is bound | Up to the balance, like a lost paper voucher |
| Forwarded or stolen e-mail voucher | Medium | Low–Medium | Device confirmation code; limits; revocable devices | A compromised mailbox |
| Online stolen-card purchases, card testing | High | Medium | 3-D Secure; velocity; 24 h cap and no card binding; dispute → block | Friendly fraud |
| Rooted or modified phone | Medium | Low | No secrets; server verifies everything; limits | The user's own permissions |
| Stolen manager phone | Medium | Medium | Device revocation; step-up; four-eyes | Until revoked, with PIN known |
| Network attacker (MITM) | Low | Medium | TLS, HSTS, pinning to ISRG roots; nothing reusable in the traffic | — |
| Compromised web server | Low–Medium | High | Keys not extractable (no cloning); append-only DB grants; off-site chain anchors; crypto-service anomaly alerts | Fake entries while in control, detected afterwards |
| Leaked database or backup | Medium | Medium | No key material; hashed secrets; encrypted PII; backups encrypted in a separate account | Metadata exposure (GDPR notification) |
| Manufacturer key leak | Low | High for one key set | Two-level keys; one key set per manufacturer; compromise playbook (§8.4) | Clonable until swapped; clones cannot spend after `compromised` |
| Tap-domain loss | Low | **Very high** (all cards dead) | 10-year registration, registrar lock, monitoring (§19) | — |
| Insider at platform | Low | High | Separation of duties; dual control; FIDO2; audit to an off-site sink | Two colluding custodians |

### 13.4 Risk rules (synchronous, plus a nightly report)

1. Velocity: more than 3 debits per voucher per hour.
2. RF UID mismatch: reject; suspend the card after two occurrences.
3. SUN counter jump > 50 since the last tap: flag (heavy reading or skimming).
4. Rebind followed by a debit within 24 h: flag, notify.
5. Overrides: any attempt refused by the caps, or more than 3 per employee per week: notify the owner.
6. Sales without a card-terminal or online reference outside opening hours: flag.
7. A guest e-mail belonging to a staff user, or used on more than 3 vouchers: flag.
8. Any tap of a card from a `compromised` batch: possession only, swap prompt.

---

## 14. Data model (final)

Only new or changed tables are listed. MySQL 8, UUID keys, amounts in cents, UTC timestamps.

| Table | Key columns | Notes |
|---|---|---|
| `gift_cards` (vouchers) | + `reference` (unique per restaurant), status + `awaiting_card`/`cancelled`/`closed`, `customer_id` optional, `lock_version` | Existing money columns stay. The `nfc_*`, `public_token`, `replaced_*` columns are frozen and dropped after the sunset. |
| `gift_card_transactions` (ledger) | + `presentment_id` UNIQUE, `override_id` UNIQUE, `payment_id`, `chain_seq`, `prev_hash`, `entry_hash` | Append-only (triggers, grants). Single-entry per voucher (R6). |
| `payments` | `voucher_id, method (cash, card_terminal, online), psp, psp_payment_id UNIQUE, amount, status, received_by, device_id, terminal_ref` | Every sale and reload references one |
| `media` | `voucher_id, type (nfc_card, email_voucher, printable_qr, legacy_token), role (spend, recovery), status (active, suspended, revoked), card_id UNIQUE NULL, secret_hash, secret_ciphertext, created_by, revoked_by/at/reason` | For `nfc_card`, the effective status is the card's state (one source of truth) |
| `media_devices` | `medium_id, device_cookie_hash, confirmed_at, revoked_at` | E-mail voucher device confirmations |
| `cards` | `uid BINARY(7) UNIQUE, chip_type, batch_id NULL, key_set_id NULL, restaurant_id, state, state_changed_at, sdm_counter, originality_sig, successor_card_id` | CHECK constraint on state; index (batch_id, state). `batch_id` and `key_set_id` are NULL only for legacy cards. |
| `card_events` | `card_id, from_state, to_state, reason, actor_id, device_id, request_id, ref_type/ref_id, created_at` | Append-only, hash-chained with the audit log |
| `card_batches` | See §8.1 | — |
| `key_sets`, `key_references`, `key_ceremonies` | Version, provider label, KCV, status; ceremony minutes | **Never** key material |
| `presentments` | `purpose, method, level, medium_id, card_id, rf_uid, sdm_counter, device_id, user_id, restaurant_id, status, expires_at, consumed_at` | Single use |
| `authorizations` | `kind (override, four_eyes_sale, recovery, resume), voucher_id, requested_by, approved_by, step_up_ref, guest_presentment_id, reason, max_amount, expires_at, consumed_at` | One table for every approval that needs a second person, a step-up or a guest confirmation |
| `contacts`, `contact_confirmations` | Contact: `voucher_id, customer_id, confirmed_at, revoked_at`. Confirmation: `token_hash, purpose (register, change, recovery, override, suspend, resume), expires_at, used_at` | E-mail links are single-use and count as guest presentments (`email_link`) |
| `online_orders`, `webhook_events` | Order data; PSP event id UNIQUE | Exactly-once webhooks |
| `customers` | + `email_confirmed_at`, encrypted e-mail and name, `email_blind_index` | — |
| `devices`, `device_keys` | + role (`pos`, `station`), step-up public key | No attestation in v2 (R15) |
| `audit_logs` | + `chain_seq`, `prev_hash`, `entry_hash` | Append-only |
| `risk_events` | Rule, severity, subject, context, status | — |
| `restaurant_settings` | + the limits (§6.3, within platform bounds), four-eyes threshold, low-stock threshold; − `card_number_prefix`, `lock_nfc_tags_after_write`, `enforce_nfc_uid_binding` | — |

---

## 15. API (v1, changes only)

| Endpoint | Purpose |
|---|---|
| `POST /presentments`, `POST /presentments/{id}/complete` | Start (with relay bytes or QR) and finish a presentment. Replaces `POST /scan`. |
| `POST /vouchers` | Create with payment (cash / terminal), optional e-mail, form (card / printable / e-mail) |
| `POST /vouchers/{id}/cards` | Bind a card `{bind_presentment_id, select_presentment_id?, replaces_card_id?}`. A select presentment is required when the voucher already existed before this visit; `replaces_card_id` handles replacement (§11.6). |
| `POST /vouchers/{id}/redemptions`, `/reloads` | Debits need `presentment_id` or an override authorization; reloads need a payment. **Transfers between vouchers are removed in v2.** |
| `POST /vouchers/{id}/contact`, `POST /contacts/confirm` | Register a recovery contact (§11.7) |
| `POST /vouchers/{id}/printable` | Re-issue the printable QR: digital vouchers only; guest `select` presentment required; refused if the voucher has a card |
| `POST /media/{id}/revoke`, `/suspend`, `/resume` | Medium status; resume rules in §7.2. Guests suspend from their contact page. |
| `POST /cards/receive` | Confirm a delivery `{presentment_id, counted_quantity}`; while the batch is `on_hold`, each further call with a card's presentment checks in that card |
| `POST /presentments` with `purpose = verify`; `GET /batches`, `GET /batches/{id}/counts` | Card info (state, batch, voucher) from a tap; stock |
| `POST /authorizations`, `POST /authorizations/{id}/approve` | Overrides, four-eyes sales, recovery approvals |
| `POST /shop/{restaurant}/orders`, `POST /webhooks/{psp}` | Online sales |
| **Public** `GET t.giftcardpro.at/{k}?e&m` | Balance page after SUN verification (throttled) |
| **Public** `GET /v/{token}` | E-mail voucher page |
| **Admin** `/admin/key-sets`, `/admin/batches/*`, `/admin/stations/*`, `/admin/personalization/*` | Platform operations |

**Deprecated and then removed:**
- `POST /scan` (legacy only);
- `POST /cards/{id}/redeem|reload|transfer` without a scan ticket (refused after Phase 0), and transfers entirely in v2;
- `/cards/{id}/nfc*`, `/cards/{id}/qr`, `/cards/{id}/replace`;
- `GET /public/cards/{token}` (legacy tokens only, until the sunset).

---

## 16. Migration, legacy sunset and code removal

### 16.1 Data

| Today | After migration |
|---|---|
| `gift_cards` row | The same voucher (same id). `card_number` becomes its `reference`. |
| `public_token` (tag URL, printed QR, e-mail link) | **One** `legacy_token` medium with `secret_hash = SHA-256(token)`. Revoking it kills the tag, the printed QR and old e-mail links together. The plain column is cleared. |
| NTAG213/215/216 binding | A `cards` row (chip type legacy, no batch, state `active`) linked to that `legacy_token` medium |
| NTAG 424 personalised with external tools | Only if any exist (R14): a `cards` row with key set v0, spending only through a valid SUN, never with the bare token. Otherwise this path is not built. |
| Customer e-mail on a voucher | An **unconfirmed** contact. The guest receives a confirmation e-mail. It becomes a recovery contact (card vouchers) or a spending e-mail voucher (vouchers without a tag) only after confirmation. |
| `nfc_write_attempts`, `nfc_scans`, `replaced_by_id` | Kept read-only as history |
| `default_validity_months = 36` | The default becomes no expiry for **new** vouchers. Existing expiries wait for the legal review (audit blocker 1). |

### 16.2 Legacy sunset

| When | Rule |
|---|---|
| T0: first premium cards live | NTAG21x writing off everywhere. Legacy media spend within legacy limits (§6.3). Every manager tap on a legacy card offers a one-tap swap. |
| T0 + 9 months | Owners get the list of legacy vouchers with a balance; confirmed contacts get a swap invitation. |
| T0 + 12 months | Legacy media become view-only. A swap still takes one tap, and **no balance is ever forfeited**. |

### 16.3 Code removal order

1. **Phase 0 (flags, on today's model):**
   - a minimal `scan_tickets` table: `/scan` returns a single-use 60-second ticket, and redeem, reload and transfer require it;
   - the ledger stores the ticket id under a unique index;
   - no waiter manual lookup;
   - `bindUnverified` off.

   Phases 2–3 generalise the tickets into presentments.
2. **When binding by tap is live:** hide the dashboard writer, the programming station, the print page and the app writer.
3. **One stable release later:** delete about 6 700 lines (§3.4). Migrations stay.
4. **After the sunset:** delete the legacy scan paths and the frozen voucher columns.

---

## 17. Implementation phases and effort

For one experienced engineer who knows the code base, including tests **[Assessment]**.

| Phase | Content | Days |
|---|---|---|
| **0** | Close today's bypasses on the current model (§16.3 step 1) | 6–8 |
| **1** | Crypto service, Google Cloud HSM, AN10922 + AN12196 with NXP vectors, key sets, ceremony tooling; remove `.env` keys | 10–14 |
| **2** | Schema: references, media, cards + lifecycle, card events, batches, presentments, payments, append-only + hash chain; backfill and verification | 9–12 |
| **3** | Presentment service, SUN v2 on the tap domain, guest balance page, limit model, risk rules | 7–10 |
| **4** | Live authentication: server protocol, Android `IsoDep` and iOS ISO 7816 relay, latency tests | 12–16 |
| **5** | App: sell, add card, replace, register, receive, card info, override; step-up; contacts and e-mail confirmations; authorizations. Dashboard: vouchers and media, batches and stock, owner reports | 14–18 |
| **6** | Station mode (personalisation + per-card QA), batch acceptance, platform batch admin; manifest import when needed | 10–14 |
| **7** | Legacy migration and sunset tooling; removal of the writer, card numbers, print page, replace-by-transfer | 4–6 |
| **8** | E-mail voucher v2 (device confirmation, rotating QR, recovery code), printable QR, rewritten e-mail templates without balances | 4–6 |
| **9** | Pilot readiness: pinning, off-site audit anchors, reconciliation report, penetration-test fixes, runbooks, owner documentation | 10–14 |
| | **Pilot scope (0–9)** | **86–118** |
| **10** | Online shop: PSP connected accounts, checkout, webhooks, refunds, disputes, fraud rules | 15–20 |
| | **Total** | **101–138** |

- **Compared with the draft:** 143–199 days including wallets, the double-entry ledger and the enterprise controls. The simplifications in §4.3 (44–64 days, wallets included) minus about 2–3 days for the lifecycle, batch and receipt additions give **42–61 days less**, without weakening any control in §13.
- **Calendar:**
  - with two engineers, about 2–3 months of engineering. Allow **3–4 months calendar** to the pilot, because of HSM setup, card-supplier samples and penetration-test scheduling **[Assessment]**;
  - the 3 November 2026 launch target is only reachable with **today's model plus Phase 0 and the audit blockers**;
  - v2 then follows as a migration, which §16 is designed for.
- **External:**
  - penetration test before the pilot;
  - cryptographic review of Phases 1, 4 and 6;
  - Google Cloud HSM (a few euros per month **[Vendor]**);
  - card supplier samples and print runs;
  - legal opinion (§20).

---

## 18. Out of scope, and how each fits in later

| Deferred | Extension point (additive, no redesign) |
|---|---|
| Apple Wallet, Google Wallet | New `media.type` values; a queued job updates passes after ledger commits; Google rotating barcodes can reuse the rotating-QR verifier |
| Restaurant chains, cross-location acceptance | `organization_id` on restaurants and vouchers; acceptance rules on the voucher; batches per organisation |
| Double-entry ledger, inter-location settlement | Migration from the append-only per-voucher ledger (each entry becomes a balanced pair) |
| Loyalty, memberships | New account tables using the same media, presentments and cards |
| Offline terminals | A terminal with NXP SAM AV3 verifying locally within floor limits; phones never |
| Device attestation | A new `device_keys.attestation` column and per-role enforcement |
| All-in-HSM (T3) | The crypto service's API is provider-independent; a new key set on another HSM |
| Card reuse | A transition `revoked → in_inventory` after re-personalisation at a station; deliberately not built |
| DESFire EV3 (hotel doors, proximity check) | New `cards.chip_type`; same presentment model |

---

## 19. Operational runbooks (to be written in Phase 9)

1. **Key ceremony**: generation, import, KCV check, custodian rotation.
2. **Batch acceptance**: sampling, approval, rejection handling.
3. **Delivery**: shipment, lost pack, restaurant receipt.
4. **Crypto service or HSM unavailable**: two instances, alerting, the HSM provider status; card transactions pause, QR vouchers and overrides for registered vouchers continue; message to restaurants.
5. **Compromised batch or key set** (§8.4).
6. **Lost or stolen manager phone**: device revocation.
7. **Suspected insider fraud**: audit export, chain verification.
8. **Tap domain**: renewal (10 years, auto-renew, registrar lock), certificate monitoring, DNS change control.
9. **Backup and restore**: encrypted, off-site, monthly restore test.

---

## 20. Open non-architecture items and change log

**Open (they do not change the architecture):**
- legal opinion on expiry (and the existing 36-month vouchers), online withdrawal rights, VAT voucher type (single-purpose), the maximum voucher value;
- choice of payment provider (Stripe or Mollie);
- card supplier, artwork and minimum order quantity;
- naming three key custodians;
- registering the tap domain.

**Architecture decision records:**

| ADR | Date | Decision |
|---|---|---|
| ADR-000 | 28 Sep 2026 | v2 architecture frozen as this document |

---

## 21. Sources

**This repository:** the files listed in §3 (code at commit `0493784`); `docs/architecture/ntag424-platform-architecture.md` (cryptographic detail), `ntag424-due-diligence.md`, `docs/reports/2026-09-28-investor-grade-audit.md`.

**Vendors:**
- NXP: [NTAG 424 DNA data sheet](https://www.nxp.com/docs/en/data-sheet/NT4H2421Gx.pdf), [AN12196](https://www.nxp.com/docs/en/application-note/AN12196.pdf), [AN10922](https://www.nxp.com/docs/en/application-note/AN10922.pdf)
- Google Cloud: [raw symmetric encryption (imported keys)](https://docs.cloud.google.com/kms/docs/raw-encryption), [Cloud KMS quotas](https://docs.cloud.google.com/kms/quotas), [pricing](https://cloud.google.com/kms/pricing)
- Apple: [NFCISO7816Tag](https://developer.apple.com/documentation/corenfc/nfciso7816tag)
- Chrome: [Web NFC](https://developer.chrome.com/docs/capabilities/nfc)
- Android: [IsoDep](https://developer.android.com/reference/android/nfc/tech/IsoDep)
- Stripe: [Merchant of record in Connect](https://docs.stripe.com/connect/merchant-of-record), [Direct charges](https://docs.stripe.com/connect/direct-charges)

**Law** (not legal advice):
- [WKO: Gutscheine – Befristung](https://www.wko.at/vertragsrecht/gutscheine-befristung)
- [Directive (EU) 2016/1065 (voucher VAT)](https://eur-lex.europa.eu/eli/dir/2016/1065/oj)
- [Delegated Regulation (EU) 2018/389 (strong customer authentication)](https://eur-lex.europa.eu/eli/reg_del/2018/389/oj)
