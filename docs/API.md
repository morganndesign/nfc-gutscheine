# API reference — v1

Base URL: `https://<domain>/api/v1` · JSON only · UTF-8 · amounts in **minor units (cents)**, strict integers ·
timestamps ISO 8601 (UTC) · IDs UUID.

Routes: `backend/routes/api.php`. Resource shapes: `backend/app/Http/Resources/*`, mirrored field by field in
`dashboard/src/lib/api/types.ts`.

## Concepts

- **Voucher** — the account that holds a balance. `kind` is `card` or `digital`; `status` is `active`, `blocked` or
  `expired`. An *empty* voucher is an `active` voucher with `balance` 0 (there is no separate status).
  `voucher_number` is an internal 16-digit number for staff and support. It is never printed on a voucher and is
  never accepted as a credential.
- **Medium** — how a voucher is presented. Today the only medium is the **printable QR** of a digital voucher
  (`GCPV1.` + 43 base64url characters = a 256-bit random secret). The server stores only its SHA-256 hash; the
  payload is returned once, in the response of the sale.
- **Presentment** — proof that a voucher's medium is here, now. Every debit consumes one. Single use, valid 60
  seconds, bound to restaurant, voucher, purpose, user and device.
- **Payment** — how a sale or reload was paid: `cash`, `card_terminal`, `bank_transfer`, `complimentary`.
- **Ledger** — `voucher_transactions` (`issue`, `redemption`, `reload`, `reversal`). Ledger, payments and audit log
  are append-only and hash-chained.

## Authentication

### Browser (dashboard, web till) — Sanctum SPA cookies

```http
GET  /sanctum/csrf-cookie                     → sets the XSRF-TOKEN cookie
POST /api/v1/auth/login                       header X-XSRF-TOKEN: <cookie value>
     {"email":"…","password":"…","remember":false}
```

The session cookie is `httpOnly`, `Secure`, `SameSite=Lax`. Every state-changing request sends `X-XSRF-TOKEN`.
Requests must come from a host in `SANCTUM_STATEFUL_DOMAINS`. A session is pinned to the `X-Device-Id` it first
sent; another id on the same session cookie signs the session out (`401`). A session restored from a "remember me"
cookie is accepted only on an active device this person has used before; otherwise `401` and a new sign-in.

### Integrations (POS, accounting) — API tokens

An owner creates a token under **Settings → API** and sends it as `Authorization: Bearer gcp_…`. A token acts as the
user who created it, restricted to the abilities chosen (a subset of that user's permissions), expires after at
most `API_TOKEN_MAX_DAYS` and can be revoked at any time. Platform administrators cannot create or use tokens.

### Native waiter app (GiftCard Waiter) — device-bound tokens

```http
POST /api/v1/auth/token
     {"email":"…","password":"…","device_id":"<16–64 chars [A-Za-z0-9-]>","device_name":"Pixel 7","platform":"android"|"ios"}
→ 201 {"data": {"token": "gcp_…", "expires_at": "…", "user": SessionUser}}
```

Send the token as `Authorization: Bearer …` together with the same `X-Device-Id`. The token:

- has the ability `vouchers.redeem`; for roles with `vouchers.sell` (managers, owners) also `vouchers.sell`. The
  role is checked on every request as well, and once a day, when the token is renewed, its abilities follow the
  role;
- reaches only these method and path pairs (`EnforceDeviceToken`); anything else answers `403 FORBIDDEN`:

  | Method | Path |
  |---|---|
  | GET | `/auth/me` |
  | POST | `/auth/logout` |
  | GET | `/devices/current` |
  | POST | `/presentments` |
  | POST | `/vouchers/{voucher}/redemptions` |
  | GET | `/vouchers/{voucher}/redemptions/{idempotencyKey}` |
  | POST | `/vouchers` (sale; needs `vouchers.sell`) |

- works only with the `X-Device-Id` it was issued for (another id → `401 UNAUTHENTICATED`);
- stops at once when the device is revoked under **Devices** (`403 DEVICE_REVOKED`) and works again when it is
  restored;
- expires after `DEVICE_TOKEN_DAYS` (30) without use and is renewed while the phone is used;
- is replaced when the same person signs in again on the same phone; `POST /auth/logout` revokes it; a password
  reset or change revokes it.

Sign-in has the same lockout, rate limit and account checks as `/auth/login`. A deactivated account gets
`401 ACCOUNT_DEACTIVATED` here and on every later request with its token. Platform administrators and roles without
`vouchers.redeem` get `403 FORBIDDEN`. Device tokens are not listed under Settings → API; platform administrators
see them under `/admin/api-tokens` (`kind: device`).

### Sign-in failures

A wrong password, an unknown address and a temporarily locked account all answer the same
`422 VALIDATION_FAILED` with the same message on `email`. The password is always hashed, so the timing is the same
too. After `LOGIN_LOCKOUT_THRESHOLD` (10) consecutive failures the account is locked for `LOGIN_LOCKOUT_MINUTES`
(15).

## Common headers

| Header | Direction | Meaning |
|---|---|---|
| `Idempotency-Key` | request | **Required** for `POST /vouchers`, `POST /vouchers/{id}/redemptions` and `POST /vouchers/{id}/reloads` (8–96 characters `[A-Za-z0-9-_.]`). Use a UUID per logical attempt. A retry with the same key returns the original result (`"replayed": true`, HTTP 200) instead of booking twice; the same key for a different request → `409 IDEMPOTENCY_CONFLICT`. A key that should be looked up with `GET /vouchers/{id}/redemptions/{key}` must match `[A-Za-z0-9_-]{16,100}` (a UUID does). |
| `X-Device-Id` | request | Stable random id of the terminal (16–64 characters `[A-Za-z0-9-]`). Registers the device in the restaurant; a revoked device gets `403 DEVICE_REVOKED`. Required with a device token. |
| `X-Request-Id` | both | Correlation id (8–64 characters; echoed, generated if absent). Stored in the audit log. |
| `Retry-After` | response | On `429` from a rate limiter. |

## Errors

```json
{ "message": "The voucher balance is insufficient for this amount.",
  "code": "INSUFFICIENT_BALANCE",
  "context": { "balance": 3150, "requested": 3151 } }
```

`context` is present only when it has content.

| HTTP | `code` | When |
|---|---|---|
| 400 | `IDEMPOTENCY_KEY_REQUIRED` | Missing or malformed `Idempotency-Key` |
| 401 | `UNAUTHENTICATED` | No or expired session or token; device token with another `X-Device-Id`; session used from another device |
| 401 | `ACCOUNT_DEACTIVATED` | Waiter app sign-in and every request with a device token of a deactivated account |
| 403 | `FORBIDDEN` | Missing permission, or a device token outside its allowed requests |
| 403 | `TENANT_NOT_RESOLVED` | Restaurant endpoint called without a restaurant (platform administrators) |
| 403 | `TENANT_MISMATCH` | A record of another restaurant was addressed |
| 403 | `RESTAURANT_SUSPENDED` | The restaurant is suspended |
| 403 | `DEVICE_REVOKED` | The terminal was revoked |
| 403 | `ROLE_ASSIGNMENT_FORBIDDEN` | Role or token beyond your own rank or permissions; platform administrator creating a token |
| 403 | `COMPLIMENTARY_NOT_ALLOWED` | `complimentary` payment without `vouchers.sell_complimentary` |
| 404 | `NOT_FOUND` | Unknown resource, or one of another restaurant |
| 409 | `IDEMPOTENCY_CONFLICT` | Key reused for a different request |
| 409 | `INVALID_VOUCHER_STATE` | Status change not allowed in the current status |
| 409 | `TRANSACTION_NOT_REVERSIBLE` | Wrong type or already reversed |
| 409 | `IMMUTABLE_RECORD` | Attempt to change an append-only record |
| 409 | `RESTAURANT_NOT_DELETABLE`, `INVITATION_NOT_POSSIBLE` | Platform administration (see there) |
| 419 | `CSRF_TOKEN_MISMATCH` | Fetch `/sanctum/csrf-cookie` again and retry |
| 422 | `VALIDATION_FAILED` | `errors` holds the field messages (also every failed sign-in) |
| 422 | `MEDIUM_NOT_RECOGNIZED` | The scanned text is not a valid voucher of this restaurant (unknown, revoked and foreign look the same) |
| 422 | `PRESENTMENT_METHOD_UNAVAILABLE` | The method has no verifier (`live_auth`) |
| 422 | `PRESENTMENT_METHOD_NOT_ALLOWED` | The voucher's kind cannot be spent with this method |
| 422 | `PRESENTMENT_INVALID` | The presentment cannot pay for this redemption; `context.reason`: `not_found`, `already_used`, `expired`, `wrong_purpose`, `wrong_voucher`, `other_user`, `other_device`, `method_not_allowed_for_kind`, `medium_revoked` |
| 422 | `VOUCHER_BLOCKED`, `VOUCHER_EXPIRED`, `VOUCHER_NOT_REDEEMABLE` | Voucher status |
| 422 | `INSUFFICIENT_BALANCE`, `INVALID_AMOUNT`, `BALANCE_LIMIT_EXCEEDED`, `RELOAD_NOT_ALLOWED` | Business rules |
| 422 | `DEBIT_LIMIT_EXCEEDED` | `context.limit`: `per_transaction` or `per_voucher_per_day`, `context.max`, for the daily limit also `context.remaining` |
| 422 | `INVITATION_NOT_DELIVERED`, `MAIL_NOT_DELIVERED`, `MAIL_RECIPIENT_REJECTED` | Platform administration (see there) |
| 429 | `TOO_MANY_REQUESTS` | Rate limiter (`retry_after`) |
| 429 | `PRESENTMENT_THROTTLED` | Too many failed presentments on this restaurant, user and device (`context.retry_after`) |
| 429 | `VELOCITY_LIMIT_EXCEEDED` | Redemptions per voucher per hour reached (`context.retry_after`: seconds until a slot frees) |

## Rate limits

| Limiter | Limit | Applies to |
|---|---|---|
| `login` | 5/min per e-mail + IP, 30/min per IP | `/auth/login`, `/auth/token` |
| `password-reset` | 5/min per IP | `/auth/forgot-password`, `/auth/reset-password` |
| `app-config` | 60/min per IP | `/app/config` |
| `presentment` | 90/min per user and `X-Device-Id` | `POST /presentments` |
| `voucher-operation` | 90/min per user and `X-Device-Id` | sale, redemption, reload, redemption outcome |
| `api` | 240/min per user | every authenticated request |

Failed presentments (the scanned text proves nothing) count separately: after `PRESENTMENT_FAILURE_LIMIT` (10)
within `PRESENTMENT_FAILURE_DECAY` (300 s) per restaurant, user and device, `POST /presentments` answers
`429 PRESENTMENT_THROTTLED`. Other guests' scans behind the same public IP address never count.

## Pagination

List endpoints accept `page` and `per_page` (≤ 100) and return:

```json
{ "data": [ … ], "links": { … }, "meta": { "current_page": 1, "last_page": 4, "per_page": 25, "total": 88 } }
```

---

## Endpoints

Permissions in brackets. All endpoints except *Public* and *Auth* sign-in require authentication; restaurant
endpoints also require a restaurant (platform administrators get `403 TENANT_NOT_RESOLVED`).

### Auth

| Method | Path | |
|---|---|---|
| POST | `/auth/login` | `{email, password, remember?}` → `{data: SessionUser}` |
| POST | `/auth/token` | Native waiter app sign-in (above) → `201 {data: {token, expires_at, user}}` |
| POST | `/auth/logout` | Ends the session, or revokes the current token |
| GET | `/auth/me` | `SessionUser`: `id, name, email, locale, role {slug, name}, is_platform_admin, permissions[]` (with a token: only what the token may do), `restaurant {id, name, slug, currency, timezone, locale, status, settings}`, `platform {support_email, notice}` |
| PUT | `/auth/profile` | `{name?, locale? (en \| de)}` |
| PUT | `/auth/password` | `{current_password, password, password_confirmation}` — revokes every token and "remember me" of this person |
| POST | `/auth/forgot-password` | `{email}` — always the same `200`; the link is sent from the queue, only to active accounts that accepted their invitation |
| POST | `/auth/reset-password` | `{token, email, password, password_confirmation}` — also accepts an invitation (activates the account); revokes every token and "remember me". Every failure answers the same `422` |

Reset and invitation links carry the token in the URL fragment (`/reset-password#token=…&email=…`), which the
browser never sends to a server.

### Presentments `[vouchers.redeem]`

```http
POST /presentments
{ "purpose": "spend", "method": "printable_qr", "credential": "GCPV1.q7Jx…" }
```

| Field | |
|---|---|
| `purpose` | `spend` |
| `method` | `printable_qr` (verified); `live_auth` exists for physical cards and answers `422 PRESENTMENT_METHOD_UNAVAILABLE` until its verifier exists |
| `credential` | The scanned QR text (max. 512 characters) |

```json
→ 201 { "data": {
    "id": "…", "purpose": "spend", "method": "printable_qr", "level": "A1",
    "expires_at": "2026-09-29T12:01:00+00:00", "expires_in": 60,
    "voucher": { "id": "…", "kind": "digital", "restaurant_name": "Trattoria Bella Vista",
      "voucher_number": "1223 5616 2557 6350", "status": "active", "currency": "EUR", "balance": 3390,
      "expires_at": null, "is_expired": false, "blocked_reason": null,
      "allow_partial_redemption": true, "max_debit_per_transaction": 25000,
      "actions": { "redeem": true } } } }
```

`expires_in` is the number of seconds left as seen by the server; clients count down from receipt, independent of
their own clock. The voucher part (`PresentedVoucher`) never contains customer data. Response header
`Cache-Control: no-store, private`.

Rules: the presentment is valid 60 seconds and for one debit. It is bound to this restaurant, this voucher, the
purpose, the user and the device (a presentment made without a device can only be used without one). Spending
rules by kind: a `digital` voucher is spent only with a QR method, a `card` voucher only with `live_auth`. A failed
presentment is recorded in the audit log (`presentment.failed`) and counts towards the lockout.

### Vouchers

| Method | Path | Permission | Body / notes |
|---|---|---|---|
| GET | `/vouchers` | vouchers.view | `search` (voucher number digits, recipient, notes, customer), `status[]` or comma list (`active`, `blocked`, `expired`), `kind`, `customer_id`, `created_from/to`, `expires_from/to`, `min_balance`, `max_balance`, `sort` (±`created_at`, ±`balance`, ±`expires_at`, ±`voucher_number`, ±`last_used_at`), `page`, `per_page` |
| GET | `/vouchers/export` | vouchers.export | Same filters → streamed CSV (`;`, UTF-8 BOM, decimal comma for German locales, readable status names, formula-injection safe) |
| POST | `/vouchers` | vouchers.sell | **Idempotency-Key** · sale of a digital voucher, below |
| GET | `/vouchers/{id}` | vouchers.view | `Voucher` with `customer`, `issued_by`, `media[]`, `payments[]` |
| PATCH | `/vouchers/{id}` | vouchers.update | `{customer_id?, recipient_name?, notes?}` |
| POST | `/vouchers/{id}/redemptions` | vouchers.redeem | **Idempotency-Key** · below |
| GET | `/vouchers/{id}/redemptions/{idempotencyKey}` | vouchers.redeem | Outcome of one of the caller's own redemption attempts, below |
| POST | `/vouchers/{id}/reloads` | vouchers.reload | **Idempotency-Key** · `{amount, payment: {method, reference?, reason?}, note?}` → `201 {data: {voucher, transaction}, replayed}` |
| POST | `/vouchers/{id}/block` | vouchers.block | `{reason}` (3–500 characters) |
| POST | `/vouchers/{id}/unblock` | vouchers.unblock | Back to `active`, or to `expired` when the expiry date passed while it was blocked |
| POST | `/vouchers/{id}/expire` | vouchers.expire | `{reason}` — only `active` vouchers; **the balance is kept** |
| POST | `/vouchers/{id}/reinstate` | vouchers.reinstate | `{reason, expires_on?}` — only `expired` vouchers; `expires_on` (`YYYY-MM-DD`, after today) is the new last valid day in the restaurant's timezone, missing or `null` = no expiry |
| GET | `/vouchers/{id}/history` | vouchers.view | Ledger entries and status events, newest first: `{id, kind: transaction \| event, type, label, amount, balance_after, reference, note, payment_method, reversed, user, device, created_at}` |

`Voucher`: `id, kind, voucher_number, voucher_number_formatted, status, currency, initial_value, balance,
total_loaded, total_redeemed, expires_at, is_expired, blocked_at, blocked_reason, expired_at, recipient_name,
notes, customer, issued_by, media[] {id, type, role, status, created_at, revoked_at}, payments[], last_used_at,
created_at, updated_at`. `total_loaded` = sale + reloads.

**Expiry.** Without a validity setting a voucher has no expiry. With one (`validity_months`, at least 36) the last
valid day is set at the sale, in the restaurant's timezone. At expiry the voucher becomes `expired` and keeps its
balance; an owner can reinstate it.

#### Sale

```http
POST /vouchers
Idempotency-Key: 7b1c…
{ "value": 5000, "form": "printable",
  "payment": { "method": "card_terminal", "reference": "4711" },
  "customer": { "first_name": "Anna", "email": "anna@example.com" },
  "recipient_name": "Anna", "notes": "Birthday" }
```

| Field | |
|---|---|
| `value` | Minor units; within the restaurant's `min_voucher_value` and `max_voucher_balance` |
| `form` | `printable` (a digital voucher with a printable QR) |
| `payment.method` | `cash`, `card_terminal` (needs `reference`: terminal receipt), `bank_transfer` (needs `reference`), `complimentary` (needs `reason`, 3–500 characters, and `vouchers.sell_complimentary`) |
| `customer_id` or `customer` | Optional: an existing customer, or a new one (`first_name, last_name, email, phone, marketing_consent`) |
| `recipient_name`, `notes` | Optional |

```json
→ 201 { "data": Voucher, "transaction": Transaction, "payment": Payment,
        "printable": { "payload": "GCPV1.q7Jx…", "qr_svg": "<svg …>" }, "replayed": false }
```

Without `vouchers.view` (e.g. a manager's app token) `data` is only `{id, kind, balance, currency}`.
`printable.payload` is returned only here and cannot be fetched again; the print sheet shows the QR, the
restaurant and the value sold (ADR-003), never the voucher number. A retry with the same key returns the same sale
(`"replayed": true`, 200). When the retry comes from the same user and device within 15 minutes and the voucher is
still active and unused, it carries a fresh QR and the unseen one is revoked; otherwise `printable` is `null`.

#### Redemption

```http
POST /vouchers/{voucher}/redemptions
Idempotency-Key: 3f0e…
{ "amount": 1850, "presentment_id": "…", "reference": "Bill 4711", "note": null }
```

```json
→ 201 { "data": { "voucher": Voucher | PresentedVoucher, "transaction": Transaction }, "replayed": false }
```

The voucher part is the full `Voucher` for users with `vouchers.view`, otherwise `PresentedVoucher`. In one
database transaction the server locks the presentment and the voucher row, looks the idempotency key up again
(a retry that waited on the lock replays the first result), consumes the presentment, checks status, balance,
partial redemption, the per-redemption and per-day limits and the hourly limit, and appends the ledger entry. A
redemption that is refused leaves the presentment unused; it stays valid until it expires.

#### Redemption outcome

```http
GET /vouchers/{voucher}/redemptions/{idempotencyKey}
→ 200 { "data": { "status": "not_booked" } }
→ 200 { "data": { "status": "booked", "voucher": PresentedVoucher, "transaction": Transaction } }
```

A till whose request went unanswered asks here instead of sending the debit again. Only the caller's own attempts
on that voucher are visible; asking never books anything. `not_booked` is final only once the attempt can no
longer be running on the server; clients wait 60 seconds after their last request before treating it as final.
`Cache-Control: no-store, private`.

#### Example with curl

```bash
P=$(curl -s -X POST https://app.example.com/api/v1/presentments \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE" -H "Content-Type: application/json" -H "Accept: application/json" \
  -d "{\"purpose\":\"spend\",\"method\":\"printable_qr\",\"credential\":\"$QR\"}")
curl -X POST "https://app.example.com/api/v1/vouchers/$(echo "$P" | jq -r .data.voucher.id)/redemptions" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE" -H "Content-Type: application/json" -H "Accept: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d "{\"amount\": 1850, \"presentment_id\": \"$(echo "$P" | jq -r .data.id)\", \"reference\": \"Bill 4711\"}"
```

### Transactions

| Method | Path | Permission | |
|---|---|---|---|
| GET | `/transactions` | transactions.view | `type[]` or comma list (`issue`, `redemption`, `reload`, `reversal`), `voucher_id`, `user_id`, `from`, `to` (restaurant-local dates), `search` (reference or voucher number) |
| GET | `/transactions/export` | transactions.export | CSV with readable type names (`Sale`, `Redemption`, `Reload`, `Reversal`) and the payment method |
| GET | `/transactions/{id}` | transactions.view | |
| POST | `/transactions/{id}/reverse` | transactions.reverse | `{reason}` — a new, opposite entry for a redemption or reload; at most once per entry, within the balance cap → `201 {data: Transaction}` |

`Transaction`: `id, type, type_label, amount` (signed), `balance_before, balance_after, currency, reference, note,
reversed, reversed_at, reversible, related_transaction_id, payment, voucher {id, kind, voucher_number, status},
user, device, created_at`. `reversed` is derived from the reversal entry that points at the original; no entry is
ever changed. `Payment`: `id, method, method_label, amount, currency, reference, reason, created_at`.

### Dashboard `[dashboard.view]`

| Method | Path | |
|---|---|---|
| GET | `/dashboard/stats` | `currency, vouchers_sold, vouchers_sold_this_month, vouchers_active, vouchers_empty, vouchers_blocked, vouchers_expired, outstanding_balance, outstanding_vouchers, today_transactions, today_redeemed, monthly_revenue, previous_month_revenue, monthly_redeemed, expiring_soon` |
| GET | `/dashboard/charts?days=7\|30\|90` | `daily[] {date, sold, redeemed, transactions}`, `monthly[] {month, revenue, redeemed}` (12 months), `status_distribution[] {status, count, balance}` |
| GET | `/dashboard/activity?limit=10` | Latest transactions (max. 50) |

### Customers

| Method | Path | Permission | |
|---|---|---|---|
| GET | `/customers` | customers.view | `search` |
| POST | `/customers` | customers.manage | `{first_name, last_name?, email?, phone?, notes?, marketing_consent?}` |
| GET | `/customers/{id}` | customers.view | `{data: Customer, vouchers: Voucher[]}` |
| PATCH | `/customers/{id}` | customers.manage | Same fields; anonymized customers cannot be edited (`409`) |
| POST | `/customers/{id}/anonymize` | customers.manage | GDPR erasure: personal data, recipient names of their vouchers and their e-mail address in the notification log are removed; the ledger stays intact |

### Team, roles, devices

| Method | Path | Permission |
|---|---|---|
| GET | `/roles` | users.view |
| GET / POST | `/users` | users.view / users.manage — POST `{name, email, role: owner \| manager \| waiter, password?, locale?}`; without a password the person gets an invitation (72 h link) |
| GET / PATCH | `/users/{id}` | users.view / users.manage |
| POST | `/users/{id}/deactivate` · `/activate` · `/password-reset` | users.manage — deactivation revokes tokens and sessions; `password-reset` sends the invitation again to people who never signed in |
| GET | `/devices` | devices.view |
| GET | `/devices/current` | any — the device of this request, or `null` |
| PATCH | `/devices/{id}` | devices.manage — `{name?, type? (phone, tablet, desktop, pos, integration)}` |
| POST | `/devices/{id}/revoke` · `/restore` | devices.manage — revoking also ends "remember me" of its users |

### Settings `[settings.manage]`

| Method | Path | |
|---|---|---|
| GET | `/settings` | Restaurant and voucher settings (with the platform ceilings) |
| PUT | `/settings/restaurant` | Profile, address, `country`, `timezone`, `locale` (`de-AT`, `de-DE`, `de-CH`, `en-GB`, `en-US`) |
| PUT | `/settings/vouchers` | `validity_months` (`null` = no expiry, otherwise 36–360), `min_voucher_value`, `max_voucher_balance`, `max_debit_per_transaction`, `max_debit_per_voucher_per_day` (each at most the platform ceiling), `max_redemptions_per_voucher_per_hour` (0 = off), `allow_reload`, `allow_partial_redemption`, `send_customer_emails`, `brand_color`, `receipt_footer` |
| GET | `/settings/notification-templates` | Effective guest e-mail templates (`voucher_issued`, `voucher_reloaded`, `voucher_expiring`) |
| PUT | `/settings/notification-templates/{key}` | `{subject, body, is_active?, locale? (en \| de)}` — creates a restaurant override |

Guest e-mails confirm a sale or reload like a receipt: amount, restaurant, date and payment method (placeholders `amount`, `date`, `payment_method`). They never contain anything that proves or spends the voucher: no QR payload, voucher number, link, token or code, and no balance.

| Method | Path | Permission | |
|---|---|---|---|
| GET / POST | `/api-tokens` | api_tokens.manage | POST `{name, abilities[], expires_at?}` → `{data: ApiToken, plain_text_token}` (shown **once**) |
| POST | `/api-tokens/{id}/revoke` | api_tokens.manage | |
| GET | `/audit-logs` | audit.view | `action` (prefix), `user_id`, `auditable_id`, `from`, `to` |

### Public

| Method | Path | |
|---|---|---|
| GET | `/app/config?platform=android\|ios&version=2.0.0` | Waiter app start-up configuration → `{data: {min_version: {android, ios}, update_required, maintenance_notice, support_email}}`. `update_required` is `null` without `platform` and `version`. Minimum versions are system settings (`app.min_version.*`). `Cache-Control: public, max-age=60` |
| GET | `/up` (outside `/api/v1`) | Health check: database and cache |

There is no public voucher page and no public voucher lookup.

### Platform administration `[platform.restaurants.manage]`

Platform administrators operate restaurants; they never act inside a restaurant and never touch vouchers.

| Method | Path | |
|---|---|---|
| GET | `/admin/stats` | `restaurants_total, restaurants_active, restaurants_archived, vouchers_total, vouchers_active, transactions_this_month, volume_sold_this_month` |
| GET | `/admin/restaurants?search=&status=active\|suspended\|archived` | Each with `owner {…, invitation}` and `archived_at` |
| POST | `/admin/restaurants` | `{name, slug?, …, currency? (EUR, CHF, USD, GBP), owner: {name, email, password?}}` — creates the restaurant and the owner account and sends the invitation → `201 {data, owner}` |
| GET | `/admin/restaurants/{id}` | Also archived ones: `{data, users[], business_data {vouchers, transactions, customers}}` |
| PATCH | `/admin/restaurants/{id}` | Profile fields, `plan`, `currency` |
| POST | `/admin/restaurants/{id}/suspend` `{reason}` · `/reactivate` | "Disable" / "Enable" |
| POST | `/admin/restaurants/{id}/archive` `{reason?}` · `/restore` | Archive = soft delete: hidden, users and devices locked out, data kept |
| DELETE | `/admin/restaurants/{id}` | `{confirm: "<slug>"}` — permanent; `409 RESTAURANT_NOT_DELETABLE` (counts in `context`) when vouchers, transactions or customers exist. The audit trail is kept |
| POST | `/admin/restaurants/{id}/invitation` · `/admin/restaurants/{id}/users/{user}/invitation` | `{name?, email?}` — a new invitation (the previous link stops working; corrects a mistyped address). Sent from the queue: `202` while queued, `200` when sent, `422 INVITATION_NOT_DELIVERED` when the mail server refused it or the platform only logs e-mails; `409 INVITATION_NOT_POSSIBLE` for accepted, disabled or archived accounts |
| GET | `/admin/api-tokens?restaurant_id=&active=` | Every restaurant's tokens, integration and device (`kind`) |
| POST | `/admin/api-tokens/{id}/revoke` | Incident response |
| GET | `/admin/audit-logs?restaurant_id=&action=` | `[platform.audit.view]`, action = prefix |
| GET / PUT | `/admin/system-settings` | `[platform.settings.manage]` — PUT `{settings: [{key, value}]}` |
| GET | `/admin/mail` | `[platform.settings.manage]` → `{mailer, delivers, from_address, from_name, host, port, problem}` (no credentials) |
| POST | `/admin/mail/test` | `[platform.settings.manage]` `{to?}` — test e-mail to `to` or the signed-in administrator; the recipient is validated first (with `MAIL_VERIFY_DOMAINS`, its domain must have a mail server). `422 MAIL_RECIPIENT_REJECTED` (550–553), `422 MAIL_NOT_DELIVERED` for other failures |

Invitations: the account exists from the start with an unknown random password. The e-mail carries a single-use
token of the `invitations` password broker (own table `invitation_tokens`, stored hashed, valid 72 h; a new
invitation replaces it). Choosing a password with `POST /auth/reset-password` activates the account
(`user.invitation_accepted` in the audit log). Every attempt is recorded in `notification_logs`
(`template_key = staff_invitation`). The e-mail uses the restaurant's language when a translation exists
(`de-*` → `de`, `en-*` → `en`), otherwise `MAIL_LOCALE` (default `de`). Wording:
`backend/lang/<locale>/invitation.php` and `backend/lang/<locale>.json`; a new language is added to
`giftcard.mail_locales`.
