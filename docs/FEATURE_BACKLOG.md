# GiftCard Pro — Future Feature Backlog

> **These are future product features. They are NOT part of production readiness.**
> Do not implement them now. Do not let them delay launch.

## General rule

Production readiness and platform stability always come before new features. No feature from this backlog may
delay a production release. A feature is started only when the production version is stable and the user asks for
it explicitly; until then the feature set is frozen (fixes for production issues only).

Every feature here must follow the existing ground rules when it is built: money in integer cents, append-only
ledger, idempotent writes, tenant isolation, generic physical cards, Android/iPhone parity, and German/English/Bosnian
copy.

**Complexity scale:** S = days · M = 1–2 weeks · L = 3–6 weeks · XL = more than 6 weeks (one developer, including
tests).

## Overview

| # | Feature | Phase | Priority | Complexity |
|---|---|---|---|---|
| 1.1 | Apple Wallet / Google Wallet pass | 1 | ★★★★★ | L |
| 1.2 | Personal gift message | 1 | ★★★★★ | S |
| 1.3 | Scheduled gift delivery | 1 | ★★★★★ | M |
| 1.4 | Low card stock alert | 1 | ★★★★☆ | S |
| 1.5 | NFC problem report | 1 | ★★★★☆ | M |
| 2.1 | Birthday credit | 2 | ★★★★★ | M |
| 2.2 | Marketing campaigns | 2 | ★★★★☆ | L |
| 2.3 | Wallet push updates | 2 | ★★★★☆ | M |
| 3.1 | Customer loyalty program | 3 | ★★★★☆ | XL |
| 3.2 | Corporate gift cards | 3 | ★★★★★ | L |
| 3.3 | Gift subscription | 3 | ★★★☆☆ | L |
| 3.4 | Analytics | 3 | ★★★★★ | M |

---

## Phase 1 — Immediately after launch

### 1.1 Apple Wallet / Google Wallet pass

- **Purpose:** Guests save their gift voucher to Apple Wallet or Google Wallet. This is a Wallet pass (a barcode
  card in the wallet app), not NFC.
- **Business value:** A premium customer experience, the voucher is always at hand, it gets used more often, and the
  restaurant's branding is on the guest's phone.
- **Technical complexity:** L.
  - Apple: a signed `.pkpass` needs a Pass Type ID certificate. The certificate is a secret: it lives with the
    signing keys and is never committed. Google: a Wallet issuer account and signed JWT "Save to Google Wallet" links.
  - The pass shows the voucher QR code, so it is a credential. It is offered only through the same channels that
    already show the QR code (the printable voucher, the purchase e-mail), never on the public balance page.
  - A pass must stop working when the voucher is blocked, refunded or replaced.
  - Restaurant logo and brand colour come from the existing branding settings.
- **Priority:** ★★★★★
- **Suggested phase:** 1. Static passes first; live balance updates are 2.3.

### 1.2 Personal gift message

- **Purpose:** During the purchase, the buyer enters a recipient name ("To: Anna") and a short message ("Happy
  Birthday ❤️"). Both appear in the purchase e-mail and on the printable voucher.
- **Business value:** Very small to build and of great perceived value. It turns a voucher into a gift.
- **Technical complexity:** S.
  - Vouchers already have a `recipient_name`, so only the message is new: a length limit and plain-text output only
    (escaped in e-mail and PDF; no HTML, no links).
  - The sale form, the waiter app sale screen, the printable template and the e-mail template each need the new
    field.
- **Priority:** ★★★★★
- **Suggested phase:** 1 (first feature after launch).

### 1.3 Scheduled gift delivery

- **Purpose:** The customer buys today and chooses a delivery date and time. GiftCard Pro e-mails the voucher to the
  recipient at that moment. It suits birthdays, Christmas, Valentine's Day and Mother's Day.
- **Business value:** It captures early and last-minute gift purchases and has strong seasonal sales potential.
- **Technical complexity:** M.
  - A scheduled delivery record, sent by the existing scheduler and queue. Sending must be safe to retry: one
    delivery, never two.
  - Times are in the restaurant's time zone.
  - The voucher is sold and paid at purchase time, so liability and the ledger do not change. Only the e-mail is
    deferred.
  - Before sending, the buyer can change the time or the recipient address, or cancel the delivery.
  - Failed deliveries show up in the existing failed-jobs and ops alerts.
- **Priority:** ★★★★★
- **Suggested phase:** 1 (best together with 1.2).

### 1.4 Low card stock alert

- **Purpose:** The restaurant gets a warning such as "Only 18 NFC cards remaining. Order more cards." and can order
  with one click.
- **Business value:** Restaurants never run out of cards, and the alert drives card orders.
- **Technical complexity:** S.
  - The data is already there: cards in the `available` state per restaurant.
  - Needs a per-restaurant threshold, a daily scheduled check that notifies once until stock goes back up, and a
    dashboard banner.
  - "Order" creates the existing card batch order for the platform, so it adds no new lifecycle.
- **Priority:** ★★★★☆
- **Suggested phase:** 1.

### 1.5 NFC problem report

- **Purpose:** A "Report NFC problem" action in the waiter app. It sends the restaurant, card ID, device, timestamp,
  recent NFC log lines and app version.
- **Business value:** Support becomes much easier, because problems with real chips and phones arrive with the facts
  attached.
- **Technical complexity:** M.
  - A small authenticated endpoint for app tokens, plus a list for the platform admin.
  - Logs are sent with privacy in mind: no keys, no full card UID, no SUN/CMAC data, no session tokens. The app
    keeps a short ring buffer of sanitised NFC events.
  - Rate-limited per device. Android and iPhone must collect the same fields.
- **Priority:** ★★★★☆
- **Suggested phase:** 1.

---

## Phase 2 — Loyalty

### 2.1 Birthday credit

- **Purpose:** The restaurant sets a birthday bonus (€10, €20 or a custom amount). The system credits it to the
  guest's card on their birthday. It is optional and set per restaurant.
- **Business value:** It brings guests back and is a strong reason to register a card.
- **Technical complexity:** M.
  - Needs the guest's birthday and their consent for it (GDPR), and it is included in the existing erasure.
  - The bonus is booked as complimentary value. It is not paid-in money, so a refund never pays it out, which matches
    the current refund rule. It counts toward liability and shows separately in reports.
  - Guards: once per guest per year (idempotent per year), within the restaurant's limits, and only on active
    vouchers.
- **Priority:** ★★★★★
- **Suggested phase:** 2.

### 2.2 Marketing campaigns

- **Purpose:** Send promotions to card holders, for example a double-value weekend, a Christmas bonus, a free coffee
  after a recharge, or a bonus reload campaign.
- **Business value:** More visits and more reloads in quiet periods.
- **Technical complexity:** L.
  - Marketing consent per guest, kept separate from transactional e-mail, with an unsubscribe link (GDPR, Austrian
    TKG §174).
  - A rules engine for bonus credits (time window, minimum reload, cap per guest). Every bonus is booked as
    complimentary value, as in 2.1.
  - E-mail sending at volume needs bounce handling and sending limits.
- **Priority:** ★★★★☆
- **Suggested phase:** 2.

### 2.3 Wallet push updates

- **Purpose:** When the balance changes, the Wallet pass updates automatically.
- **Business value:** The guest always sees the current balance without asking at the till.
- **Technical complexity:** M.
  - Apple: the PassKit web service (device registration, update endpoint) and APNs pushes. Google: Wallet object
    updates through the API.
  - Pushes are triggered from ledger events through the queue and must be safe to retry. The balance in a pass is for
    display only; the till always checks the server.
- **Priority:** ★★★★☆
- **Suggested phase:** 2 (needs 1.1).

---

## Phase 3 — Premium

### 3.1 Customer loyalty program

- **Purpose:** Reward points, levels and VIP members.
- **Business value:** Long-term guest retention, and a premium plan to sell.
- **Technical complexity:** XL.
  - A separate points ledger, never mixed with the money ledger, plus rules for earning, redeeming and expiry, levels,
    and the tax and accounting treatment of rewards.
  - The waiter app needs new screens on both Android and iPhone.
- **Priority:** ★★★★☆
- **Suggested phase:** 3.

### 3.2 Corporate gift cards

- **Purpose:** Bulk purchases for companies (employee gifts): CSV import of recipients, an invoice, and delivery to
  every recipient.
- **Business value:** Large orders per sale and recurring corporate customers (Christmas, anniversaries).
- **Technical complexity:** L.
  - One order creates many vouchers in one idempotent operation, with validation of the CSV (row errors reported,
    nothing half-imported).
  - The invoice must meet Austrian invoice requirements, and payment is by invoice: vouchers are activated only once
    payment is recorded.
  - Delivery reuses 1.3. Fits the existing per-sale limits or needs a separate corporate limit.
- **Priority:** ★★★★★
- **Suggested phase:** 3. It is high priority, but depends on 1.2 and 1.3.

### 3.3 Gift subscription

- **Purpose:** Automatic monthly gift vouchers, e.g. €25 every month to a family member.
- **Business value:** Recurring revenue and predictable sales.
- **Technical complexity:** L.
  - Needs recurring online payment (a payment provider with stored mandates, SCA), so it depends on online sales.
  - Handles failed payments, pausing and cancellation, and delivery through 1.3.
- **Priority:** ★★★☆☆
- **Suggested phase:** 3.

### 3.4 Analytics

- **Purpose:** A restaurant dashboard with average card value, average redemption, inactive cards, top-selling
  periods, outstanding liability and customer retention.
- **Business value:** Owners see what the program brings in, which is the strongest argument for keeping and
  upgrading the subscription.
- **Technical complexity:** M.
  - The ledger already holds the data, and the dashboard already has stats, cash-up and liability figures.
  - Needs aggregate queries (or nightly rollups on large tenants) that are strictly tenant-scoped and checked on MySQL
    for performance.
  - No personal data leaves the aggregates.
- **Priority:** ★★★★★
- **Suggested phase:** 3. The parts that only read existing data (liability, inactive cards) can come earlier.
