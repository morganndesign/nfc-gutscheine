# GiftCard Pro: security and issuing architecture

**Status:** design input, superseded for scope and plan by `giftcard-pro-v2-architecture.md` (frozen v2.2) and `docs/implementation/v2-implementation-plan.md`. Its controls (device enrolment, step-up, four-eyes, audit, risk) are carried into the v2 architecture. GiftCard Pro has no production data; nothing here describes a migration (ADR-002).
**Date:** 28 September 2026.
**Baseline:** repository at `40fb84a`, version 1.4.3 in development.
**Scope:** the 20 requirements of the *Enterprise Security & Issuing Architecture* brief. For each one this document records:

- what the product does today (checked in the code);
- the decision taken;
- the design;
- the cost to the restaurant workflow.

Only where noted does it rely on the investor-grade audit (`docs/reports/2026-09-28-investor-grade-audit.md`, finding ids such as S8 and P2).

**Guiding rule.** Every control is judged on two questions:

1. Which attacker does it stop, and how would that attacker get around it?
2. What does it cost the waiter or manager at the table?

A control that slows every sale for a threat that is unlikely is replaced by one that only triggers on risk.

---

## 0. Summary

| # | Requirement | Today | Decision |
|---|---|---|---|
| 1 | Voucher ≠ card | One row (`gift_cards`) is voucher **and** medium: balance, card number, QR token and NFC UID live together. "Replace card" creates a new card and moves the balance. | **Adopt.** `gift_cards` becomes the **voucher**; a new `voucher_media` table holds NFC / QR / number / wallet credentials. Replacing a card = revoke one medium, attach another; there is no balance transfer. |
| 2 | Tag carries only UUID + secret + version | Tag carries `https://<domain>/c/<public_token>` (UUID v4, 122 random bits). No balance or PII on the tag. | **Adopt, adapted.** The tag carries a versioned URL with a 256-bit medium secret. It needs no separate UUID: the secret identifies the medium. The server stores only its hash. |
| 3 | Unique cryptographic identity | UUID v4 token; random Luhn card numbers; NTAG 424 keys diversified per UID. Tokens stored in clear. | **Adopt.** 256-bit secrets, hashed at rest (SHA-256), versioned. A master key for 424 moves to a key store with a key version. |
| 4 | Server-side issuing only | Already true: server creates number, token and URL; the app only writes. | **Keep.** Formalised as an invariant with tests. |
| 5 | Two-phase activation | Card is active on creation; the tag is bound only after verification. | **Adopt.** Medium lifecycle `created → writing → verifying → active \| write_failed \| revoked`. The voucher is active once paid; each credential works only while its medium is active. |
| 6 | Read-back verification | Done for UID + URL (dashboard and app). | **Keep + extend.** NTAG 424: read-back must include a fresh, server-verified SUN MAC. |
| 7 | Device registration | Devices auto-register on first use; the device id is chosen by the client; no keys. | **Adopt for issuing devices.** Hardware-backed key pair, platform attestation, owner approval, signed issuing requests. Redemption devices stay as they are. |
| 8 | Manager authentication | Being signed in is enough. Biometrics only unlock the UI. | **Adopt.** Step-up per policy. Biometric = a device key that needs user authentication, so the **server** can verify it. Server-verified PIN for shared phones. |
| 9 | Immutable audit trail | `audit_logs`: complete who/what/IP/device/request id, but it is a normal, mutable table. | **Adopt.** Append-only (DB triggers + no-update grants), hash chain, daily anchor off-site. Retention per law, not "forever" (GDPR). |
| 10 | Fraud detection | Throttles and velocity for redemption only; no issuing analytics. | **Adopt.** Asynchronous rule engine → `risk_events` → alerts. Main target: *issuing without payment* by insiders. |
| 11 | Configurable policies | Card value min/max, max balance, redemption velocity, UID binding, lock tags. | **Adopt.** One `security_policy` per restaurant with safe defaults. |
| 12 | Four-eyes approval | None. | **Adopt.** Vouchers above the threshold are `pending_approval` until a second person approves, on the same phone or remotely. |
| 13 | GPS & location intelligence | None (IP only). | **Adopt as an optional risk signal only**, per restaurant and only at the moment of issuing. Never blocks. Legally sensitive for employees in Austria (§13.3). |
| 14 | Online issuing | None (no shop, no payment). | **Design now, build later.** Order → payment webhook → voucher. Fulfilment queue for physical cards. |
| 15 | Delivery-independent voucher | Card number, QR/link and one NFC tag, fixed to the card. | **Adopt** through #1. Wallet passes as further media. |
| 16 | NTAG 424 DNA | SUN verification with diversified keys and counter replay protection. **Bypassable** with `method: qr/api` (S8). Provisioning only with external tools. | **Adopt.** Per-medium allowed read methods (closes S8). Later: provisioning through a server-driven APDU relay; keys never leave the server. |
| 17 | Root/jailbreak detection | None. | **Adopt as a server-verified attestation** (Play Integrity / App Attest) at device enrolment and per issuing session. Local checks are advisory only. |
| 18 | Certificate pinning | None (system trust store; development builds allow user CAs). | **Adopt with a safe pin set** (ISRG roots + backup) and a planned-rotation process. |
| 19 | Screenshot protection | None. | **Adopt** `FLAG_SECURE` on PIN, approval and issuing screens (Android); hide content in the app switcher (iOS). No secret is ever displayed anyway. |
| 20 | Zero trust | Mostly true for money (server-side amounts, idempotency, tenant isolation, role checks per request). Gaps: client-chosen device id, bearer tokens, UID trust on NTAG21x. | **Adopt as design rules** (§3) plus the controls above. |

**Effect on the restaurant workflow.** For a manager with an approved phone and "biometric" policy, selling a card stays one screen: amount, **one fingerprint** (valid for a short step-up window, so a series of sales needs one), hold the card, done. Extra steps appear only when a risk rule fires:

- value above the approval threshold → a second person;
- a new phone → owner approval once;
- a failed attestation → programming disabled on that phone.

---

## 1. Threat model

### 1.1 Assets

| Asset | Why it matters |
|---|---|
| Voucher balance (the ledger) | The money the restaurant owes guests. Stealing it = stealing from the guest or the restaurant. |
| Right to issue value | Whoever can create a voucher without payment prints money. |
| Media credentials (tag secret, QR, number, wallet) | Whoever holds one can spend the voucher. |
| 424 master keys | Whoever holds one can forge every secure card. |
| Audit trail | Evidence for disputes, insurance, tax audit and employee cases. |
| Guest personal data (e-mail, name) | GDPR. |

### 1.2 Attackers and their most likely moves

| Attacker | Most likely abuse | Primary controls |
|---|---|---|
| **Manager / owner (insider)** | Issue a voucher **without payment** (for self or friends) and redeem it; issue high values; expire a guest's voucher and pay out cash; "replace" a guest's card to themselves. | Payment reference + daily reconciliation (§10.3); four-eyes above threshold (§12); issuing limits per hour/day (§11); immutable audit (§9); expiry/replace are reversible and logged (audit P6/P7). |
| **Waiter** | Redeem a guest's card twice; redeem their own card for friends; issue cards (not allowed). | Server-side idempotency; role and token abilities; issuing only on approved devices with step-up. |
| **Guest** | Clone their own NFC card and spend it twice (impossible: one balance); forge a card of higher value (impossible: the tag carries no value); dispute a redemption. | Balance on the server only; ledger + audit per redemption. |
| **Third party near a guest** | Read a guest's NFC tag (1–4 cm, any phone) or photograph the QR, then spend the balance. | Media secrets per method (§2, §16): an NFC medium only accepts NFC reads with UID binding; secure cards use SUN. Guests can freeze a medium. |
| **External attacker** | Credential stuffing on staff accounts; stolen or lost phone; token theft; MITM on a restaurant's Wi-Fi; enumerate card numbers or tokens. | Login throttles + lockout; device binding + revocation; attested device key for issuing; certificate pinning; 256-bit secrets, throttled lookups. |
| **Platform insider / database leak** | Copy tokens from the DB; change balances; delete logs. | Hashed secrets; ledger invariant checks; append-only audit with an off-site hash anchor; 424 keys outside the DB. |

### 1.3 What cannot be solved with software, stated honestly

- **An NTAG21x card is a static credential.** Anyone who reads it can copy the URL; blank "magic" tags can even imitate the UID. UID binding makes cloning harder; it does not make it impossible. Only **NTAG 424 DNA (SUN)** gives a per-tap cryptographic proof. Recommendation: 424 for vouchers above a value the restaurant chooses; NTAG21x as the low-cost default.
- **A manager with a legitimate device and legitimate biometrics can still issue without payment.** Controls make it visible and bounded: reconciliation, limits, four-eyes, alerts. They cannot make it impossible without a POS integration that proves the payment.
- **Location of an honest phone can be faked.** GPS is a risk signal, never a gate (§13).

---

## 2. Target domain model (requirements 1, 2, 3, 5, 15)

### 2.1 Voucher and media

```
Voucher (gift_cards, renamed in code only: App\Models\Voucher alias)
  id (UUID, internal, never a credential)
  restaurant_id, currency
  status: pending_payment | pending_approval | active | redeemed | blocked | expired | cancelled
  balance, initial_value, totals          ← unchanged ledger fields
  expires_at, activated_at, …
  issued_by, issued_on_device, payment_reference, delivery (in_person | digital | physical | digital_physical)
  └─ Transactions (gift_card_transactions)  ← unchanged, balance = Σ amounts
  └─ Media (voucher_media)                  ← new
       id (UUID)
       type: nfc_ntag21x | nfc_ntag424 | qr | number | apple_wallet | google_wallet | link
       status: created | writing | verifying | active | write_failed | revoked
       secret_hash (SHA-256 of the 256-bit secret; null for `number`)
       secret_version (format version of the secret)
       nfc_uid, nfc_tag_type, nfc_locked, sun_counter, key_version    (NFC only)
       allowed_methods: e.g. {nfc} for NFC media, {qr, link} for QR  (closes S8)
       created_by, activated_by, activated_at, revoked_by, revoked_at, revoke_reason
       label (e.g. "Card ••6488", "Apple Wallet")
```

- **Balance belongs only to the voucher.** Media never carry or cache value.
- **The card number stays a voucher-level identifier.** It is shown on the success screen and printed on the receipt. As a credential it is a `number` medium: typed entry, throttled, and optionally allowed only for managers (policy).
- **Replacing a lost card = `revoke(old medium)` + attach a new one.** It no longer creates a new voucher, so `replaced_by_id` / balance transfer transactions are no longer needed for this case. The audit keeps both media.
- **Guest self-service (later):** "Freeze my card" on the balance page revokes that medium.

### 2.2 What a medium carries (requirement 2)

| Medium | Content | Size |
|---|---|---|
| NFC NTAG21x | `https://<domain>/c/2.<secret>`. `2` = format version; `<secret>` = 32 random bytes, base64url (43 chars). | ≈ 70 bytes; fits NTAG213 (137) |
| NFC NTAG 424 | `https://<domain>/c/4.<medium-id>?picc=<32 hex>&cmac=<16 hex>` (SUN; the tag computes both per tap). No static secret is needed: the per-tap MAC is the proof. | ≈ 110 bytes |
| QR (print / e-mail) | `https://<domain>/c/2.<secret>`, with its **own** secret, separate from the NFC medium's. | — |
| Wallet | Barcode = the wallet medium's own URL/secret; the pass is updated with the balance by the server. | — |
| Number | 16-digit random Luhn number (existing `CardNumberGenerator`). | — |

- **Never on a medium:** balance, value, owner, expiry, PIN.
- **Why no separate UUID in the URL.** The secret is 256 bits and is looked up by its hash (unique index). A UUID beside it adds nothing but length. The version prefix allows future format changes.
- **The secret is shown once.** It exists in clear only in the issuing response (to write it or print it). The server stores `SHA-256(secret)`. A database leak therefore does not let anyone produce working cards. Rewriting or reprinting a medium creates a **new** secret.

### 2.3 Separate the guest's view link from the spending credential

Today the link e-mailed to the guest and the URL on the tag are the same bearer credential (audit S8). New rule:

- Guest e-mails and the balance page use a **view-only** token (`voucher_views`, 128-bit, read-only scope). It is never accepted by `POST /scan`.
- A tag URL opened in a browser (a guest tapping their own card with their phone) shows the balance. The same URL sent to `POST /scan` is accepted only with that medium's `allowed_methods` (§16.2).

---

## 3. Zero-trust rules (requirement 20)

These rules are binding for all new code. The "today" column is from code review.

| Rule | Today |
|---|---|
| Every amount, status, limit and permission is decided by the server; the client sends intentions, never facts. | ✅ |
| Every request is checked against **role and token abilities** (and tenant). | ✅ (S2 admin tokens: fix in Phase 0) |
| Every money-moving request is idempotent, and the key is re-checked under the row lock. | ⚠ P2 open |
| Nothing the client generates is trusted as identity: device id → **attested device key** for sensitive operations. | ❌ (§7) |
| A tag's UID or URL is trusted only as far as the chip type allows: NTAG21x = static, possible clone; NTAG 424 = per-tap MAC. | ⚠ S8 |
| No secret in clear at rest: medium secrets hashed; 424 keys in a key store; PIN hashes Argon2id. | ❌ tokens in clear |
| No trust in the network: TLS everywhere, pinning in the app, HSTS; webhooks verified by signature. | ⚠ no pinning |
| No trust in the browser: CSRF, SameSite, Sanctum SPA; no secrets in URLs of logs (audit L1). | ⚠ L1 |
| Failures are closed: when a verification step cannot be performed (attestation service down, no read-back), the medium stays inactive and issuing waits, while redemption keeps working. | new |

---

## 4. Issuing workflow (requirements 4, 5, 6, 8, 12)

### 4.1 In person (dashboard or GiftCard Waiter)

```
Manager: amount (+ e-mail, + payment reference if policy)             [phone / dashboard]
   │  step-up if policy: biometric (device key needs user auth) or PIN
   ▼
POST /vouchers                         ← signed by the device key (§7), Idempotency-Key
   server: policy checks (limits, hours, device approved, attestation fresh)
           → voucher (active, or pending_approval above the threshold)
           → medium (status created), secret generated here, returned ONCE
   ▼
POST /media/{id}/writing               ← medium → writing (records UID seen, attempt id)
   phone writes the URL, reads back (fresh read), compares UID + URL
   ▼
POST /media/{id}/verify                ← read-back UID + URL (+ fresh SUN for 424)
   server: compares with its own expectation → medium active
   on mismatch / timeout: write_failed (the secret is burnt; the next attempt gets a new secret)
   ▼
Success: card number, balance, "tag verified"
```

- **The steps and endpoints of 1.4.3 (`…/nfc/check`, `…/nfc`) stay.** They become the medium endpoints; the phone's `CardProgrammer` and the dashboard's `nfc-programming.ts` keep their flow.
- **A medium in `created`, `writing` or `write_failed` is never accepted by `POST /scan`.** A half-written or intercepted tag is useless.
- **"Program later"** leaves the voucher active (the guest paid) with its number medium only.
- **Four-eyes (§12):** above the threshold the voucher is `pending_approval`. Its media can be written but stay inactive until approval, so the tag is handed over already programmed.

### 4.2 Online (requirement 14, later phase)

| Delivery | Flow |
|---|---|
| Digital only | Checkout → PSP webhook `paid` (signature-verified, idempotent) → voucher active → e-mail with QR medium + view link + wallet buttons. |
| Physical only | `paid` → voucher active, **no spendable medium** → *Awaiting programming* queue in the dashboard (programming station) → medium active → *Shipped* (tracking number) → e-mail. |
| Digital + physical | `paid` → voucher active with QR medium → physical medium attached later to the **same voucher**. |

- The voucher is created **only from the webhook**, never from the browser's return URL.
- Orders keep payment id, amount and VAT treatment. A multi-purpose voucher (Mehrzweckgutschein) carries no VAT at sale; the tax adviser confirms per restaurant.
- The PSP (e.g. Stripe, Mollie, Adyen) is chosen in the implementation phase.

---

## 5. The requirements in detail

### 5.1 Device registration (requirement 7)

**Today.**
- A device row is created on first use from `X-Device-Id`, which the client chooses: `fingerprint = sha256(restaurant | device id)`.
- Devices can be revoked, and waiter tokens are bound to them.
- A copied device id plus a stolen token works until the device is revoked.

**Design (for devices that issue; redemption-only phones are unchanged):**
1. **Enrolment.** The app creates an **EC P-256 key pair in hardware**:
   - Android: Keystore / StrongBox, non-exportable, `setUserAuthenticationRequired` according to the policy (see §5.2);
   - iOS: Secure Enclave.
2. The app sends the public key with **platform attestation**:
   - Android: Key Attestation certificate chain + Play Integrity token;
   - iOS: App Attest assertion.

   The server verifies both: genuine app, genuine device, key in hardware.
3. **Approval.**
   - The device appears in *Devices* as `pending`.
   - Owner approval (dashboard, or push to the owner's phone) moves it to `approved`, recording `approved_by`, `approved_at`, `public_key`, `key_attestation`, `registered_at`.
   - Policy `device_approval_required = false` approves automatically but still records the key.
4. **Use.**
   - Every issuing request carries `X-Device-Signature`: ECDSA over `method | path | SHA-256(body) | timestamp | nonce`. The server checks the signature, the timestamp (±60 s) and the nonce (single use, Redis, 5 min).
   - A stolen bearer token is then useless for issuing.
5. **Revocation.** It works as today; in addition the key is invalidated.

*Workflow cost:* one owner approval per new phone.

### 5.2 Manager step-up authentication (requirement 8)

| Policy `issuing_auth` | Proof the server can verify |
|---|---|
| `none` | Signed-in session on an approved device. |
| `biometric` | The device key is created with `setUserAuthenticationRequired(true)`, validity 0 or N seconds (Android) / `.biometryCurrentSet` (iOS). A valid signature therefore **proves** a successful biometric check on that device. Enrolling a new fingerprint invalidates the key (re-approval). |
| `pin` | 6-digit manager PIN, set in the dashboard. Stored Argon2id. Checked server-side on `POST /step-up`: 5 tries → 15 min lock, alerted. Suits shared phones. |
| `pin_or_biometric` | Either. |

- Step-up yields a **short-lived step-up grant**: default 10 minutes, bound to user, device and token, ended by sign-out or lock. A series of sales needs one proof.
- The existing UI-only biometric unlock (09 §7.6) stays for app unlock. It is not used as proof.

### 5.3 Audit trail (requirement 9)

**Today.**
- `audit_logs` already records user, device, action, old/new values, metadata, IP, user agent and request id.
- It is an ordinary table: updatable, deletable, and gone with the database.

**Design:**
- **Append-only:**
  - MySQL triggers `BEFORE UPDATE` / `BEFORE DELETE` → `SIGNAL SQLSTATE '45000'`;
  - the application DB user loses `UPDATE`/`DELETE` on `audit_logs`, `gift_card_transactions`, `nfc_scans` and `risk_events`;
  - GDPR anonymisation is done by a separate maintenance user, logged.
- **Tamper evidence:**
  - each row stores `prev_hash` and `hash = SHA-256(prev_hash ‖ canonical JSON of the row)`, chained per restaurant;
  - a nightly job writes the day's last hash to the off-site backup location and e-mails it to the platform operator (anchor);
  - a verifier command re-computes the chain.
- **Issuing events log:** who, when, restaurant, device (+ key id + attestation verdict), IP, GPS (if enabled), amount, voucher, medium, NFC UID, chip type, result, approver (four-eyes), step-up method, payment reference, risk score.
- **Retention.** "Permanently" conflicts with GDPR storage limitation. Transactions and issuing records are kept **7 years** (Austrian retention for accounting records, BAO § 132) and access and scan logs **1 year**. Afterwards personal fields (IP, user agent, GPS) are anonymised; hashes stay valid because the chain covers a hash of those fields. To be confirmed with the tax adviser and the DPO.

### 5.4 Fraud detection (requirement 10)

- **Architecture.** Domain events are handled asynchronously on the queue:
  - `VoucherIssued`, `MediumWriteFailed`, `StepUpFailed`, `ScanFailed`, `Redeemed`, `Expired`, `Reversed`;
  - each goes to a **rule engine** (PHP classes, config per policy), which writes `risk_events` (`restaurant_id, subject (user/device/voucher), rule, score, details, status open/ack/closed`);
  - alerts go out by e-mail/push to the owner and appear in a new dashboard view *Risk*.
- **Scores add up per subject and day.** Rules never block, except the hard policy limits of §5.5.

| Rule | Signal |
|---|---|
| Issuing volume | Count or value per user / device / hour and day above policy, or above 3× the 28-day median. |
| Unusual amount | Value above the 99th percentile of the restaurant, or round high values repeated. |
| Unusual hours | Outside the restaurant's opening hours (new setting). |
| Repeated failures | ≥ 3 write failures, PIN failures, scan refusals or 424 MAC failures per device in 10 min. |
| **Self-dealing** | Voucher issued by user X and redeemed by user X, or on device D, within 24 h. |
| **Issued without payment** | No payment reference (when the policy asks for one), or daily issued value ≠ payment total from reconciliation. |
| Expire / reverse / replace spikes | Money removed from guests' vouchers by the same user. |
| Location (optional) | Outside the geofence, or impossible travel (§5.7). |
| New device + high value | Device approved < 24 h ago issuing above the threshold. |

- **Reconciliation (the most effective control against insiders):** a daily report compares issued vouchers per payment method with the day's POS payments. The restaurant enters or imports the POS total; a POS integration comes later. Differences are alerted.

### 5.5 Security policy (requirement 11)

One record per restaurant (`restaurant_security_policies`). The owner edits it in the dashboard, and every change is audited and alerted.

| Setting | Default | Notes |
|---|---|---|
| `issuing_auth` | `biometric_or_pin` | `none` possible for single-person venues. |
| `step_up_minutes` | 10 | 0 = every sale. |
| `approval_threshold` | €500 | Four-eyes above this value (§5.6). |
| `max_cards_per_hour` | 20 per user | Hard limit (refused with a message). |
| `max_value_per_day` | €5 000 per restaurant | Hard limit; the owner raises it or approves an exception. |
| `device_approval_required` | true | §5.1 |
| `require_payment_reference` | false | "Cash / card / POS receipt no." field on issue. |
| `opening_hours` | — | For the unusual-hours rule. |
| `location_signals` | off | §5.7; needs the legal check first. |
| `secure_cards_from_value` | — | Suggest NTAG 424 for vouchers ≥ X. |
| `number_redemption` | `all_staff` | or `managers_only`. |

- Hard limits apply on the server (`POLICY_LIMIT_REACHED`); everything else is a risk signal.
- Existing settings (min/max card value, max balance, redemption velocity, UID binding, lock tags) move into the same screen.

### 5.6 Four-eyes approval (requirement 12)

1. **Issue.** A value above `approval_threshold` creates a voucher in `pending_approval`. The media are written but stay inactive; it cannot be redeemed.
2. **Approve (one of):**
   - *On the same phone:* "Approval by a second person". A second manager or the owner signs in inline and does their own step-up (PIN or biometric on their own approved device). The server enforces: approver ≠ issuer, role manager/owner, step-up valid.
   - *Remotely:* push/e-mail to the owner → approve in the dashboard.
3. **Activate.** Voucher active; media whose write was verified become active.
4. **Reject or timeout** (default 24 h): the voucher is cancelled, logged and alerted, and the guest is refunded by the restaurant.

### 5.7 Location intelligence (requirement 13)

- **Collected:** coarse location (±100 m), only at the moment of issuing, approving and programming, with the OS permission and restaurant policy `location_signals = on`. IP is recorded as today.
- **Signals:**
  - distance to the restaurant's geofence (address → lat/lng, radius, default 300 m);
  - impossible travel between consecutive events of the same user or device (> 500 km/h);
  - GPS vs IP country mismatch.
- **Result:** a risk score and alert only. **Never blocks** (location is spoofable, and indoor GPS is poor).
- **Law.**
  - Recording an employee's location is personal data and a control measure.
  - In Austria this likely needs a **works council agreement**, or the employees' consent where there is no works council (ArbVG §§ 96, 96a), plus a GDPR purpose, information notice and possibly a DPIA.
  - The feature therefore ships **off** by default, with a notice in the setting.
  - *Not legal advice; confirm with an employment lawyer before enabling.*

### 5.8 Online issuing (requirement 14)

The design is in §4.2. **New entities:**
- `orders` (restaurant, buyer e-mail, amount, delivery, PSP id, status `created → paid → fulfilled/shipped → cancelled/refunded`);
- `shipments` (address, tracking).

**Public shop page:**
- per restaurant (`/shop/<slug>`), amount presets and branding;
- no account needed; rate-limited, CAPTCHA only on abuse.

**Refund:** reverses the voucher (ledger `reversal`) and revokes all media.

### 5.9 Wallet passes (requirement 15)

- **Apple Wallet:** store-card pass signed with the pass type certificate. The barcode is a wallet medium's URL. The pass web service (`/wallet/apple/v1/…`) pushes balance updates.
- **Google Wallet:** gift card class/object via the Wallet API (service-account-signed JWT save link).
- Both are media of the voucher: revocable individually, and they show the balance only.
- NFC-enabled passes need Apple/Google programme approval and a VAS-capable reader. **Evaluation only** (see waiter-app design 13 §3).

### 5.10 NTAG 424 DNA (requirement 16)

**Today.**
- `Ntag424SunVerifier` decrypts PICCData, checks the CMAC with a per-UID diversified key and refuses replayed counters. That part is sound.
- **Gap S8:** `CardScanService` verifies the chip only for `method = nfc | link`, so sending the same card as `qr` or `api` skips it.

**Design:**
1. **Per-medium allowed methods.**
   - An `nfc_ntag424` medium accepts only a read that carries a valid, fresh SUN.
   - An `nfc_ntag21x` medium accepts only `nfc` with a matching UID (and `link` from iPhones, where the policy allows; see risk note §1.3).
   - Anything else gives `SCAN_METHOD_NOT_ALLOWED`, which is audited and scored.
   - This closes S8 without a special case.
2. **Scan ticket.**
   - A successful scan returns a short-lived, single-use `scan_ticket` (60 s, bound to voucher, medium, device and user).
   - `POST /vouchers/{id}/redeem` requires it. Redemption then always follows a verified read (audit A04).
   - Manual number entry obtains a ticket through the `number` medium.
3. **Keys.**
   - The master keys (meta-read, file-read) move from environment variables into a key store: at minimum an encrypted file / secrets manager, later KMS or HSM.
   - `key_version` is stored per medium, so keys can be rotated without re-issuing old cards.
4. **Provisioning 424 in-house (later).** The phone acts as a **relay only**:
   - the server runs the ISO 7816 APDU exchange with the chip through the phone (`AuthenticateEV2First`, `ChangeKey`, `ChangeFileSettings` for SDM, write NDEF template);
   - the per-card keys never reach the phone;
   - read-back = a fresh SUN read verified by the server.
   - Cost: about 10 round trips ≈ 1–2 s on a good connection.

### 5.11 Root / jailbreak detection (requirement 17)

- Local root checks are easy to bypass. The control that counts is **server-verified attestation**:
  - Android: Play Integrity `MEETS_DEVICE_INTEGRITY` (+ `MEETS_STRONG_INTEGRITY` if the policy is strict) and Key Attestation `verifiedBootState = VERIFIED`;
  - iOS: App Attest.
- Checked at device enrolment and at the start of each issuing session (cached ≤ 24 h).
- On a failed verdict the device's issuing and programming are disabled, and an alert is raised. Redemption on that phone keeps working (policy option to block it too).
- A local check (e.g. `su` binaries, Magisk traces, Frida ports) only adds a risk signal.

### 5.12 Certificate pinning (requirement 18)

- The TLS certificate comes from Let's Encrypt via Coolify/Traefik and its key changes at each renewal. Pinning the leaf would break the app every 60–90 days.
- **Design:**
  - pin the SPKI hashes of **ISRG Root X1 and ISRG Root X2**;
  - add a **backup pin** of a second CA, used only if Let's Encrypt must be abandoned;
  - implement in Dart with a custom `SecurityContext`/`badCertificateCallback`-free check, validating the chain *and* requiring one pinned SPKI in it;
  - Android also uses `network_security_config` `<pin-set expiration="…">`.
- **Operation:**
  - the pin set expires with the app build (e.g. 12 months) and is re-shipped with each release;
  - `update_required` in `/app/config` forces an update if pins must change.
- **Development builds** keep user CAs (debugging proxies). Production builds never do.

### 5.13 Screenshot protection (requirement 19)

- **Android:** `FLAG_SECURE` on the step-up (PIN), approval, device enrolment and issuing screens, through a small channel method set when the route is shown.
- **iOS:** screenshots cannot be blocked. The app hides content when it goes inactive (privacy overlay) and detects screen recording (`isCaptured`) on those screens.
- **By design no secret is ever displayed.** The medium secret exists only between the server response and the write. The card number on the success screen is not a secret on its own (redemption by number is throttled and policy-limited).

---

## 6. Plan

Superseded by `docs/implementation/v2-implementation-plan.md`; the table below is the original estimate.

| Phase | Content | Requirements | Effort |
|---|---|---|---|
| **0: close the gaps** | Scan method rules per chip type (S8); scan ticket; admin tokens (S2); step-up = server PIN (fast path) with policy `issuing_auth`; hard issuing limits; audit append-only triggers + DB grants; hashed `public_token` lookup; FLAG_SECURE on issuing screens. | 16, 8 (PIN), 11 (part), 9 (part), 3 (part), 19 | 8–10 |
| **1: voucher and media** | `voucher_media`; version-2 secrets hashed at rest; medium lifecycle (created/writing/verifying/active/write_failed); replace = revoke + attach; view-only guest links; dashboard + app programming on media endpoints. | 1, 2, 3, 5, 6, 15 (base) | 10–12 |
| **2: trusted devices** | Hardware keys, attestation (Play Integrity / App Attest), owner approval, signed issuing requests, biometric step-up via key; certificate pinning. | 7, 8, 17, 18 | 10–12 |
| **3: risk and approval** | Policies screen; four-eyes; rule engine, `risk_events`, alerts, *Risk* view; reconciliation report; hash chain + anchor; optional location signals (after the legal check). | 9, 10, 11, 12, 13 | 12–15 |
| **4: channels** | Online shop + PSP + fulfilment queue + shipping; Apple/Google Wallet; NTAG 424 provisioning relay. | 14, 15, 16 | 20–30 |

**Order rationale.**
- Phase 0 closes proven holes with small changes.
- Phase 1 changes the data model once, before more data exists.
- Phase 2 needs Phase 1's issuing endpoints.
- Phase 3 needs the events of 1 and 2.
- Phase 4 is new product surface.

---

## 7. API sketch (new and changed)

| Endpoint | Purpose | Auth |
|---|---|---|
| `POST /vouchers` | Issue. Body: amount, delivery, e-mail, payment reference. Returns the voucher + first medium (`secret` once). | `vouchers.issue`, device signature, step-up grant, policy |
| `POST /vouchers/{id}/approve` · `/reject` | Four-eyes | `vouchers.approve`, approver ≠ issuer, step-up |
| `POST /vouchers/{id}/media` | Attach a medium (NFC, QR, wallet). Returns `secret` once. | `media.attach`, device signature, step-up |
| `POST /media/{id}/writing` · `/verify` · `/lock` · `/attempts` | Programming (today's `…/nfc/check`, `…/nfc`, `…/nfc/lock`, `…/nfc/attempts`) | `media.write` |
| `POST /media/{id}/revoke` | Lost / stolen / guest freeze | `media.revoke` (+ guest via view link, freeze only) |
| `POST /scan` | Returns voucher view + `scan_ticket`; per-medium method rules | `cards.scan` |
| `POST /vouchers/{id}/redeem` | Needs `scan_ticket` + Idempotency-Key | `cards.redeem` |
| `POST /devices/enrol` · `/devices/{id}/approve` | Device key + attestation; owner approval | app / `devices.manage` |
| `POST /step-up` | PIN or signed challenge → step-up grant | signed-in |
| `GET/PUT /security-policy` | Owner policies | `settings.manage` (owner) |
| `GET /risk-events` · `POST /risk-events/{id}/ack` | Risk view | `audit.view` |
| `POST /webhooks/psp` | Payment events (signature-verified) | PSP signature |


---

## 8. Decisions not taken (and why)

| Proposal | Decision |
|---|---|
| Card UUID **and** secret on every tag | One 256-bit secret, looked up by hash, is equivalent and shorter. A version prefix handles format changes. |
| "Challenge" verification on NTAG21x | These chips have no cryptography, so a challenge cannot be answered. Real challenge/response exists only for NTAG 424 (§5.10). |
| Blocking by GPS | Spoofable and inaccurate indoors; it would block honest staff. Risk score only. |
| Storing audit "forever" | Conflicts with GDPR storage limitation. Legal retention + anonymisation instead, with the hash chain intact. |
| Root detection as the only control | Easily bypassed. Server-verified attestation decides; local checks are signals. |
| Pinning the leaf certificate | It breaks on every Let's Encrypt renewal. Root SPKI pins + backup + planned expiry instead. |
| Step-up on every redemption | Waiters redeem dozens of times per shift. Redemption stays fast: the ledger, idempotency and scan tickets protect it. Step-up is for creating value. |

---

## 9. Acceptance criteria (for the implementation phases)

1. No code path creates or activates a voucher or medium without the server deciding. Tests call the endpoints with forged client fields (amount, status, UID, secret) and expect them to be ignored or refused.
2. `POST /scan` with an NFC medium's URL via `qr` or `api` → `SCAN_METHOD_NOT_ALLOWED`. A 424 medium without a valid fresh SUN → refused (S8 regression test).
3. A medium in `created`, `writing` or `write_failed` → never redeemable.
4. Replacing a lost card creates no ledger entries, and the old medium stops at once.
5. `UPDATE`/`DELETE` on `audit_logs` or `gift_card_transactions` fails at database level; the hash-chain verifier detects any edited row.
6. Issuing from an unapproved device, without a valid signature or step-up, or beyond a hard limit → refused with a specific code. Each case is audited.
7. Above the approval threshold: not redeemable until approved by a different person. Issuer self-approval → refused.
8. A DB dump contains no usable medium secret; attempts with dumped hashes fail.
9. A production build rejects a MITM certificate from a user-installed CA and a certificate not chaining to a pinned root.
10. Restaurant flow: the median time for "sell + program" on an approved phone with biometric policy stays ≤ current + 2 s.
