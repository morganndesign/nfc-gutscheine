# API reference — v1

Base URL: `https://<APP_DOMAIN>/api/v1` · JSON only · UTF-8 · all amounts in **minor units (cents)** ·
all timestamps ISO 8601 (UTC) · all IDs UUID.

## Authentication

### Browser (dashboard, web waiter mode) — Sanctum SPA cookies

```http
GET  /sanctum/csrf-cookie                     → sets XSRF-TOKEN cookie
POST /api/v1/auth/login                       headers: X-XSRF-TOKEN: <cookie value>
     {"email":"…","password":"…","remember":true}
```

The session cookie is `httpOnly`, `Secure`, `SameSite=Lax`. Every state-changing request must send
`X-XSRF-TOKEN`. Requests must come from a host listed in `SANCTUM_STATEFUL_DOMAINS`.

### Integrations (POS, accounting) — API tokens

Create a token under **Settings → API** (owner). Send it as:

```http
Authorization: Bearer gcp_…
```

A token acts as the user who created it, **restricted to the abilities chosen** (subset of that user's
permissions), expires after at most `API_TOKEN_MAX_DAYS`, and can be revoked at any time.

### Native waiter app (GiftCard Waiter) — device-bound tokens

```http
POST /api/v1/auth/token
     {"email":"…","password":"…","device_id":"<16–64 chars>","device_name":"Pixel 7","platform":"android"|"ios"}
→ 201 {"data": {"token": "gcp_…", "expires_at": "…", "user": SessionUser}}
```

Send the token as `Authorization: Bearer …` **together with the same `X-Device-Id`**. The token:

- can only scan and redeem (abilities `cards.scan`, `cards.redeem`) and only reaches `auth/me`, `auth/logout`,
  `scan`, `cards/{id}/redeem` and `devices/current` — even for owners;
- works only with the `X-Device-Id` it was issued for (another id → `401`);
- stops at once when the device is revoked under **Devices** (`403 DEVICE_REVOKED`) and works again when it is restored;
- expires after `DEVICE_TOKEN_DAYS` (30) without use and is renewed while the phone is used;
- is replaced when the same person signs in again on the same phone; `POST /auth/logout` revokes it.

Same lockout (`423 ACCOUNT_LOCKED`), rate limit and account checks as `/auth/login`; a deactivated account gets
`401 ACCOUNT_DEACTIVATED` here and on every later request with its token. Platform administrators
and roles without scan and redeem get `403 FORBIDDEN`. Device tokens are not listed under Settings → API.

## Common headers

| Header | Direction | Meaning |
|---|---|---|
| `Idempotency-Key` | request | **Required** for `redeem`, `reload`, `transfer`; optional for `POST /cards`. 8–96 chars `[A-Za-z0-9-_.]` (`:` is reserved for internal ledger legs), use a UUID per logical attempt. Retrying with the same key returns the original result (`"replayed": true`) instead of booking twice; reusing it for a *different* request → `409 IDEMPOTENCY_CONFLICT`. |
| `X-Device-Id` | request | Stable random id of the terminal (16–64 chars). Registers the device; revoked devices get `403 DEVICE_REVOKED`. A browser session is pinned to the device id it signed in with — a different id on the same session cookie → `401`. |
| `X-Restaurant-Id` | request | Platform administrators only: act inside a restaurant. |
| `X-Request-Id` | both | Correlation id (echoed; generated if absent). Appears in audit logs. |
| `Retry-After` | response | On `429`. |

## Errors

```json
{ "message": "The gift card balance is insufficient for this amount.",
  "code": "INSUFFICIENT_BALANCE",
  "context": { "balance": 3150, "requested": 3151 } }
```

| HTTP | `code` | When |
|---|---|---|
| 400 | `IDEMPOTENCY_KEY_REQUIRED` | Missing/invalid `Idempotency-Key` |
| 401 | `UNAUTHENTICATED` | No/expired session or token |
| 401 | `ACCOUNT_DEACTIVATED` | Waiter app only (sign-in and every request with a device token): the account was deactivated |
| 403 | `FORBIDDEN` | Missing permission |
| 403 | `TENANT_NOT_RESOLVED` | Platform admin called a restaurant endpoint without `X-Restaurant-Id` |
| 403 | `RESTAURANT_SUSPENDED` | Restaurant suspended |
| 403 | `DEVICE_REVOKED` | Terminal revoked |
| 403 | `CARD_FOREIGN_RESTAURANT` | Card belongs to another restaurant |
| 403 | `NFC_UID_MISMATCH` | Chip differs from the bound chip (suspected clone) |
| 403 | `NFC_SIGNATURE_INVALID` | NTAG 424 SUN MAC invalid / missing |
| 403 | `NFC_REPLAY_DETECTED` | NTAG 424 tap counter not increasing (copied URL) |
| 403 | `ROLE_ASSIGNMENT_FORBIDDEN` | Role/user management beyond your rank |
| 404 | `NOT_FOUND`, `CARD_NOT_FOUND` | Unknown (or other tenant's) resource |
| 409 | `INVALID_CARD_STATE` | Action not allowed in the card's status |
| 409 | `NFC_TAG_IN_USE` | The chip is linked to another usable card (this or another restaurant; `context.card_number` only for your own) |
| 409 | `NFC_ATTEMPT_INVALID` | NFC programming step without a matching open attempt (check first) |
| 409 | `NFC_CARD_ALREADY_PROGRAMMED` | Programming station (`only_if_unprogrammed`): the card got a tag on another device in the meantime |
| 409 | `IDEMPOTENCY_CONFLICT` | Key reused for a different request |
| 409 | `TRANSACTION_NOT_REVERSIBLE` | Already reversed / wrong type |
| 419 | `CSRF_TOKEN_MISMATCH` | Refresh `/sanctum/csrf-cookie` and retry |
| 422 | `VALIDATION_FAILED` | `errors` holds field messages |
| 422 | `NFC_VERIFICATION_FAILED` | Tag read back after writing does not match (`context.reason`: `URL_MISMATCH` or `TAG_SWAPPED`); nothing saved |
| 422 | `INSUFFICIENT_BALANCE`, `INVALID_AMOUNT`, `CARD_BLOCKED`, `CARD_EXPIRED`, `CARD_NOT_REDEEMABLE`, `BALANCE_LIMIT_EXCEEDED`, `RELOAD_NOT_ALLOWED` | Business rules |
| 423 | `ACCOUNT_LOCKED` | Too many failed logins (`retry_after` seconds, also in `context`) |
| 429 | `TOO_MANY_REQUESTS`, `SCAN_THROTTLED`, `VELOCITY_LIMIT_EXCEEDED` | Rate limits / fraud limits. `VELOCITY_LIMIT_EXCEEDED` carries `context.retry_after` (seconds until the card's one-hour window frees a slot) |

## Rate limits

| Limiter | Limit |
|---|---|
| `login` | 5/min per e-mail+IP, 30/min per IP (web and waiter app sign-in) |
| `app-config` | 60/min per IP |
| `password-reset` | 5/min per IP |
| `public-card` | 20/min per IP |
| `card-scan` | 90/min per user **per terminal** (`X-Device-Id`); failed or suspicious lookups (not found, foreign card, UID mismatch, bad SUN signature, replay) additionally 10 per 5 min per user and per IP |
| `card-operation` | 90/min per user per terminal |
| `api` | 240/min per user |

## Pagination

List endpoints accept `page` and `per_page` (≤ 100) and return:

```json
{ "data": [ … ], "links": { "next": "…" }, "meta": { "current_page": 1, "last_page": 4, "per_page": 25, "total": 88 } }
```

---

## Endpoints

Permissions are shown in brackets. `→` shows the response body.

### Auth

| Method | Path | |
|---|---|---|
| POST | `/auth/login` | `{email, password, remember}` → `{data: SessionUser}` |
| POST | `/auth/token` | Native waiter app sign-in (see above) → `201 {data: {token, expires_at, user}}` |
| POST | `/auth/logout` | Ends the session (or revokes the current API token) |
| GET | `/auth/me` | Session user incl. `permissions[]` and restaurant settings |
| PUT | `/auth/profile` | `{name?, locale?}` |
| PUT | `/auth/password` | `{current_password, password, password_confirmation}` — signs out other sessions |
| POST | `/auth/forgot-password` | `{email}` — always 200 (no account enumeration) |
| POST | `/auth/reset-password` | `{token, email, password, password_confirmation}` |

### Scan — the waiter entry point `[cards.scan]`

```http
POST /scan
{ "method": "nfc", "token": "https://app.example.com/c/3f2b…a6c", "nfc_uid": "04:A2:3F:1B:6C:80:12" }
```

| Field | |
|---|---|
| `method` | `nfc` · `qr` · `link` · `manual` · `api` |
| `token` | Raw URL or token read from the tag/QR (SUN `picc`/`cmac` parameters are picked up from the URL) |
| `card_number` | Instead of `token` for manual entry |
| `nfc_uid` | Chip serial number (Web NFC `serialNumber`) — enables clone detection. A `nfc` scan of a card with a bound chip **without** `nfc_uid` is refused (`NFC_UID_MISMATCH`) while *Enforce chip binding* is on |
| `picc`, `cmac` | NTAG 424 DNA SUN values (if not in the URL) |

```json
→ { "data": { "id": "…", "restaurant_name": "Trattoria Bella Vista", "card_number": "1223 5616 2557 6350",
     "status": "active", "currency": "EUR", "balance": 3390, "expires_at": "2029-09-13T21:59:59+00:00",
     "is_expired": false, "blocked_reason": null, "allow_partial_redemption": true,
     "actions": { "redeem": true, "reload": false, "history": false, "block": false, "activate": false } } }
```

No customer data is ever returned by `/scan`.

### Cards

| Method | Path | Permission | Body / notes |
|---|---|---|---|
| GET | `/cards` | cards.view | `search, status[] (csv), customer_id, created_from/to, expires_from/to, min_balance, max_balance, nfc_status (unprogrammed · unverified · verified), card_number_after, sort (±created_at, ±balance, ±expires_at, ±card_number, ±last_used_at), page, per_page` |
| GET | `/cards/export` | cards.export | Same filters → streamed CSV (`;`, UTF-8 BOM, decimal comma for German locales, readable status names, formula-injection safe) |
| POST | `/cards` | cards.create | `{value, expires_at?, customer_id? \| customer{first_name,last_name,email,phone}?, recipient_name?, notes?, activate?=true, nfc_tag_type?}` → `{data: GiftCard, transaction, nfc: {url, tag_type_hint, ndef_template}}` |
| GET | `/cards/{id}` | cards.view | |
| PATCH | `/cards/{id}` | cards.update | `{customer_id?, recipient_name?, notes?, expires_at?}` |

**Expiry semantics** (`expires_at` is a local date `YYYY-MM-DD`): the card is valid until 23:59:59 of that day in the restaurant's timezone. On `POST /cards`, *omitting* the key applies the restaurant's default validity; sending `null` explicitly creates a card without expiry. Past dates → `422`.
| POST | `/cards/{id}/redeem` | cards.redeem | **Idempotency-Key** · `{amount, reference?, note?}` → `201 {data:{card, transaction}, replayed}` |
| POST | `/cards/{id}/reload` | cards.reload | **Idempotency-Key** · `{amount, reference?, note?}` |
| POST | `/cards/{id}/transfer` | cards.transfer | **Idempotency-Key** · `{target_card_id \| target_card_number, amount? (default: all), note?}` |
| POST | `/cards/{id}/activate` | cards.activate | inactive → active |
| POST | `/cards/{id}/block` | cards.block | `{reason}` |
| POST | `/cards/{id}/unblock` | cards.unblock | |
| POST | `/cards/{id}/expire` | cards.expire | `{reason?}` — writes off the balance |
| POST | `/cards/{id}/replace` | cards.replace | `{reason, nfc_tag_type?}` → new card (201) with the remaining balance; old card `replaced` |
| GET | `/cards/{id}/history` | cards.view | Ledger + events, newest first |
| GET | `/cards/{id}/nfc` | cards.write_nfc | NFC payload (URL, NTAG 424 template, lock policy) |
| POST | `/cards/{id}/nfc/check` | cards.write_nfc | Programming step 2: `{attempt_id (uuid), uid, current_url?, only_if_unprogrammed?}` → `{data: {status: available \| already_programmed \| refused, reason, message, conflict: {card_id, card_number}?, content: blank \| this_card \| other_card \| retired_card \| stale_copy \| foreign, replaces_tag, locked, expected_url, attempt_id}}` |
| POST | `/cards/{id}/nfc` | cards.write_nfc | Record the tag. `method: web_nfc` → `{attempt_id, tag_type: ntag213 \| ntag215 \| ntag216, uid, read_back: {uid, url}}` — the chip is saved only if the tag read back is the same chip and carries exactly the card URL (`nfc.verified_at`). Optional `timings: {detect_ms, write_ms, verify_ms, total_ms}`, `only_if_unprogrammed`. `method: manual` (`tag_type` ntag21x) · `provisioned` (`ntag424_dna`, `locked?`) · `printed` (`qr_only`) — never with a `uid` |
| POST | `/cards/{id}/nfc/lock` | cards.write_nfc | `{attempt_id}` — the verified tag was made read-only (`nfc.locked`); also after `already_programmed` |
| POST | `/cards/{id}/nfc/attempts` | cards.write_nfc | Report a failure the browser saw: `{attempt_id, stage (read · check · detect · write · verify · lock · bind), result (failed · refused · cancelled), error_code, message?, uid?, tag_type?, previous_url?, read_back_url?, timings?}` → 201. The `POST` programming endpoints are limited to 180 requests per minute per user and device |
| GET | `/cards/{id}/nfc/attempts` | cards.write_nfc | Last 50 programming attempts of the card (result, stage, error, chip, type, user, time) |
| GET | `/cards/{id}/qr` | cards.write_nfc | `image/svg+xml` QR code of the card URL |

Example — redeem with curl:

```bash
curl -X POST https://app.example.com/api/v1/cards/$CARD/redeem \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"amount": 1850, "reference": "Bill 4711"}'
```

### Transactions

| Method | Path | Permission | |
|---|---|---|---|
| GET | `/transactions` | transactions.view | `type[] (csv), gift_card_id, user_id, from, to (restaurant-local dates), search` |
| GET | `/transactions/export` | transactions.export | CSV with readable type names (`Sale`, `Redemption`, `Reload`, `Transfer in/out`, …) |
| GET | `/transactions/{id}` | transactions.view | |
| POST | `/transactions/{id}/reverse` | transactions.reverse | `{reason}` — counter-entry for a redemption or reload |

### Dashboard `[dashboard.view]`

| GET | `/dashboard/stats` | KPIs: `outstanding_balance` + `outstanding_cards` (open liability and the number of cards carrying it), `monthly_revenue` / `previous_month_revenue`, `monthly_redeemed` / `today_redeemed`, cards sold (total / this month / active), `expiring_soon` |
|---|---|---|
| GET | `/dashboard/charts?days=7\|30\|90` | `daily[] {date, sold, redeemed, transactions}`, `monthly[]` (12 months), `status_distribution[]` |
| GET | `/dashboard/activity?limit=10` | Latest transactions |

### Customers

| GET `/customers` [customers.view] · POST `/customers` [customers.manage] · GET/PATCH `/customers/{id}` · POST `/customers/{id}/anonymize` (GDPR erasure; ledger stays intact) |
|---|

### Team, roles, devices

| Method | Path | Permission |
|---|---|---|
| GET | `/roles` | users.view |
| GET / POST | `/users` | users.view / users.manage — POST `{name, email, role: owner\|manager\|waiter, password?}` sends a welcome invitation (72 h link) when no password is given |
| GET / PATCH | `/users/{id}` | users.view / users.manage |
| POST | `/users/{id}/deactivate` · `/activate` · `/password-reset` | users.manage — deactivation revokes tokens and sessions; `password-reset` re-sends the invitation for users who never signed in |
| GET | `/devices` | devices.view |
| GET | `/devices/current` | any |
| PATCH | `/devices/{id}` · POST `/devices/{id}/revoke` · `/restore` | devices.manage |

### Settings `[settings.manage]`

| GET `/settings` | Restaurant + card settings |
|---|---|
| PUT `/settings/restaurant` | Profile, locale, timezone |
| PUT `/settings/cards` | Card rules (see `restaurant_settings`) |
| GET `/settings/notification-templates` | Effective templates (override or default) |
| PUT `/settings/notification-templates/{key}` | `{locale, subject, body, is_active}` — creates a restaurant override |
| GET / POST `/api-tokens`, POST `/api-tokens/{id}/revoke` | `[api_tokens.manage]` — POST returns `plain_text_token` **once** |
| GET `/audit-logs` | `[audit.view]` `action` (prefix), `user_id`, `auditable_id`, `from`, `to` |

### Public

| GET | `/public/cards/{token}` | Anonymous balance page data (masked number, balance, status, expiry, restaurant name). Can be disabled per restaurant. 20/min per IP. |
|---|---|---|
| GET | `/app/config?platform=android\|ios&version=1.2.0` | Waiter app start-up config → `{data: {min_version: {android, ios}, update_required, maintenance_notice, support_email, card_domains}}`. `update_required` is `null` without `platform`/`version`. Minimum versions are system settings (`app.min_version.*`). `Cache-Control: public, max-age=60`. |

### Platform administration `[platform.*]`

| GET | `/admin/stats` — incl. `restaurants_archived` |
|---|---|
| GET | `/admin/restaurants?search=&status=active\|suspended\|archived` — each with `owner {id, name, email, status, last_login_at, invitation}` and `archived_at` |
| POST | `/admin/restaurants` `{name, …, owner:{name, email, password?}}` — creates restaurant + owner account and e-mails the invitation; response `owner.invitation.delivery` = `sent` \| `failed` \| `logged` |
| GET | `/admin/restaurants/{id}` — also archived ones; `users` (each with `invitation`), `business_data {gift_cards, transactions, customers}` |
| PATCH | `/admin/restaurants/{id}` — profile fields plus `plan`, `currency` (currency only before the first gift card) |
| POST | `/admin/restaurants/{id}/suspend` `{reason}` · `/reactivate` ("Disable" / "Enable") |
| POST | `/admin/restaurants/{id}/archive` `{reason?}` · `/restore` — archive = soft delete: hidden, users and devices locked out, data kept |
| DELETE | `/admin/restaurants/{id}` `{confirm: "<slug>"}` — permanent; `409 RESTAURANT_NOT_DELETABLE` (with counts in `context`) when gift cards, transactions or customers exist |
| POST | `/admin/restaurants/{id}/invitation` `{name?, email?}` — owner's invitation again (new link, old one invalid; corrects a mistyped address) · `/admin/restaurants/{id}/users/{user}/invitation` for other pending accounts. `409 INVITATION_NOT_POSSIBLE` (accepted, disabled, archived), `422 INVITATION_NOT_DELIVERED` (mail server refused / log mailer) |
| GET | `/admin/audit-logs?restaurant_id=&action=` (action = prefix) |
| GET / PUT | `/admin/system-settings` — PUT `{settings: [{key, value}]}` |
| GET | `/admin/mail` → `{mailer, delivers, from_address, from_name, problem}` · POST `/admin/mail/test` sends a test e-mail to the signed-in admin |

Invitations: the account exists from the start with an unknown random password. The e-mail carries a single-use
token of the `invitations` password broker (random, stored hashed, valid 72 h; a new invitation replaces it).
Choosing a password with `POST /auth/reset-password` activates the account (`user.invitation_accepted` in the
audit log). Every attempt is recorded in `notification_logs` (`template_key = staff_invitation`).

## Resource shapes

See `dashboard/src/lib/api/types.ts` — it mirrors every resource (`GiftCard`, `ScannedCard`, `Transaction`,
`HistoryEntry`, `Customer`, `StaffUser`, `Device`, `Restaurant`, `AuditLog`, `ApiToken`, …) field by field.
