# Architecture

This document describes the code as it is. The target architecture it implements is
[architecture/giftcard-pro-v2-architecture.md](architecture/giftcard-pro-v2-architecture.md); the order in which the
remaining parts are built is [implementation/v2-implementation-plan.md](implementation/v2-implementation-plan.md).

## System overview

```
┌────────────────────┐ HTTPS (one origin) ┌─────────┐ /api /sanctum /up ┌──────────────────────────┐
│ Browser            │ ─────────────────▶ │ Gateway │ ────────────────▶ │ Laravel 12 (PHP-FPM)     │
│ · Dashboard        │                    │ (Caddy) │                   │  HTTP → Services → Models│
│ · Web till /waiter │ ◀── Next.js pages ─│         │ ── everything else ▶ Next.js 15 (standalone) │
└────────────────────┘                    └─────────┘                   └──────┬──────────┬────────┘
┌────────────────────┐   Bearer token + X-Device-Id  ▲                         │          │
│ GiftCard Waiter    │ ───────────────────────────────┘                   MySQL 8.4    Redis 7.4
│ (Android, iPhone)  │   camera → QR → presentment → redemption          (ledger,      (sessions, cache,
└────────────────────┘                                                    tenants)      queues, locks)
                                                          queue worker ─┘   scheduler ─┘
```

**One origin.** Sanctum's cookie-based SPA authentication keeps the session in an httpOnly cookie (not readable by
JavaScript), with SameSite=Lax and CSRF tokens. Serving the dashboard and the API from the same host removes CORS
entirely. The native app uses device-bound bearer tokens against the same API.

## Spending a voucher

A voucher is spent only with proof that its medium is present. Staff and guests call it a **scan** (QR) or a
**card tap** (NFC card, Phase 4); the API resource and the code call it a **presentment**. User-facing text never
says "presentment" (ADR-003): the app, the dashboard and the guides use *Scan* / *Tap card*, in German *Scannen* /
*Karte ans Handy halten*, in BHS *Skeniraj* / *Prislonite karticu uz telefon*.

```
Waiter app / web till                         API
 scan QR "GCPV1.…"  ── POST /presentments ──▶  PresentmentService::present
                                               ├ lockout check (restaurant + user + device)
                                               ├ verifier for the method (printable_qr → hash lookup in media)
                                               ├ kind rule: digital ↔ QR, card ↔ live_auth
                                               └ INSERT presentments (verified, expires in 60 s,
                                                  bound to restaurant, voucher, purpose, user, device)
 ◀── 201 {id, expires_in, voucher} ──
 enter amount
 POST /vouchers/{id}/redemptions  (Idempotency-Key, presentment_id)
                                         ──▶   RequireIdempotencyKey
                                               VoucherService::redeem
                                               ├ key already booked? → replay (200) or 409
                                               └ DB::transaction (3 attempts on deadlock)
                                                   ├ SELECT presentment FOR UPDATE, SELECT voucher FOR UPDATE
                                                   ├ key booked meanwhile? → replay
                                                   ├ consume presentment (verified → consumed; checks expiry,
                                                   │  purpose, voucher, user, device, kind, medium active)
                                                   ├ status, balance, partial rule, per-transaction and daily
                                                   │  limits, redemptions per hour
                                                   ├ INSERT voucher_transactions (hash-chained, key UNIQUE)
                                                   ├ UPDATE vouchers (balance, total_redeemed, last_used_at)
                                                   ├ INSERT audit_logs (hash-chained)
                                                   └ COMMIT → VoucherRedeemed (after commit)
 ◀── 201 {voucher, transaction} ──
 answer lost? → GET /vouchers/{id}/redemptions/{key} → booked | not_booked (never a second debit)
```

Presentment methods are verifier classes behind one interface (`PresentmentVerifier`). `printable_qr` is
implemented (`PrintableQrVerifier`, assurance level A1). `live_auth` (A3, physical cards) is an enum case without a
verifier; it is added with the crypto service and the NFC relay ([NFC.md](NFC.md)).

## Selling and reloading

`POST /vouchers` sells a **digital** voucher: one transaction records the payment, the `issue` ledger entry and the
audit entries, then issues the printable QR (`PrintableQrService`: 256-bit secret, only its SHA-256 hash stored). The
QR payload is part of that response only. Reloads record a payment the same way. Every sale and reload is
idempotent; the chain order inside a transaction is payments → ledger → audit log.

## Voucher lifecycle

```
                 sell (payment)                    reload (payment) · redeem (presentment)
   ─────────────────────────────▶  active  ◀───────────────────────────────┐
                                   │  ▲  └─────────────────────────────────┘
                     block (reason)│  │unblock (→ expired if the date passed meanwhile)
                                   ▼  │
                                 blocked
   active ── expire (owner, reason) or nightly job at the expiry date ──▶ expired   (balance kept)
   expired ── reinstate (owner, reason, new date or none) ──────────────▶ active
```

"Empty" is an `active` voucher with balance 0. Corrections are reversals: a new ledger entry that points at the
original. Nothing in the ledger, the payments or the audit log is ever updated or deleted.

## Backend layers

```
Http/Middleware   AssignRequestId → (Sanctum) → BindRememberedSignIn → EnforceDeviceToken → ResolveTenant
                  → RequireTenant → throttle → bindings → TrackDevice → can:
Http/Requests     input validation only (FormRequest)
Http/Controllers  thin: parse request → call service → return Resource
Services          business rules, transactions, locking, auditing   ← the only place state changes happen
Models            persistence, casts, relations, tenant scope, append-only guards, hash chains
Data / Support    DTOs (IssueVoucherData, PaymentData, SaleResult, TransactionResult, PrintableSecret),
                  Actor, Money, VoucherNumber, HashChain, CsvSanitizer, TenantContext
```

- **Services** — `VoucherService` owns every change of a voucher's money or status; `PresentmentService` and its
  verifiers own proof of presence; `PrintableQrService` owns QR media; `VoucherHistoryService`,
  `VoucherNumberGenerator`, `ChainVerifier`, `CredentialVerifier`, `DeviceTokenService`, `AccessRevoker`,
  `UserService`, `InvitationService`, `RestaurantService`, `DeviceService`, `ApiTokenService`, `DashboardService`,
  `VoucherNotificationService`, `AuditLogger`.
- **No repository layer.** Reused query logic lives in model scopes (`search`, `forRestaurant`, `ofType`,
  `notReversed`).
- **Actor** — every service call receives an `Actor` (user, device, IP, user agent, request id), so ledger and
  audit entries are attributable in HTTP, queue and console contexts alike.
- **Domain exceptions** — each business-rule violation is a typed exception with a stable error code
  (`INSUFFICIENT_BALANCE`, `PRESENTMENT_INVALID`, …), rendered as JSON by `bootstrap/app.php`.
- **Events** (`VoucherIssued`, `VoucherReloaded`, `VoucherRedeemed`) implement `ShouldDispatchAfterCommit`:
  listeners (guest e-mails) run only once the money movement is durable.
- **Append-only and hash-chained models** — `Payment`, `VoucherTransaction`, `AuditLog` use the `Immutable` and
  `HashChained` concerns; database triggers enforce the same rule.

## Multi-tenancy

Single database, shared schema, `restaurant_id` on every tenant-owned table.

1. `ResolveTenant` binds the authenticated user's restaurant to the request-scoped `TenantContext`. Platform
   administrators have no restaurant and never act inside one.
2. `BelongsToRestaurant` adds `RestaurantScope` (all reads filtered), stamps `restaurant_id` on create and throws
   `TenantMismatchException` when code tries to write a row into another tenant.
3. Route model binding resolves `{voucher}`, `{customer}`, `{device}`, `{transaction}` through the scope, so foreign
   ids are indistinguishable from non-existent ones (404).
4. `RequireTenant` refuses restaurant endpoints without a tenant, so a missing tenant can never widen a query.
5. Validation rules use `existsInTenant()`; services re-assert ownership (`assertOwnedByTenant`).
6. A printable QR is looked up only among the current restaurant's media.

Users are resolved before a tenant exists, so `User` is not globally scoped; every staff query filters by
`restaurant_id` explicitly and the `{user}` binding is tenant-constrained.

## Clients

### Dashboard (`dashboard/`, Next.js)

```
src/app
 ├ (auth)/login, forgot-password, reset-password     tokens read from the URL fragment
 ├ (app)/dashboard, vouchers, vouchers/new, vouchers/[id], transactions, customers, team, devices,
 │       audit, settings, account, admin/*
 └ waiter/            web till: scan QR → presentment → amount → redemption
src/lib
 ├ api/client.ts      fetch wrapper (CSRF, device id, idempotency key, typed ApiError)
 ├ api/hooks.ts       React Query hooks per domain (cache keys, invalidation)
 ├ api/types.ts       types mirroring the Laravel resources
 ├ auth.tsx           session provider, permission checks (can())
 ├ outcome.ts         which errors leave a money request's outcome unknown
 └ payment.ts, guest-copy.ts, money.ts, format.ts, regional.ts, audit.ts
src/components
 ├ ui/                shadcn/ui primitives (Radix)
 ├ vouchers/          payment fields, reload dialog, printable voucher sheet, history
 ├ waiter/            terminal, QR scanner, keypad
 └ layout/, charts/, settings/, admin/, dashboard/, common/
```

- **Server state** lives only in React Query; mutations invalidate by key prefix.
- **Forms** use React Hook Form + Zod; the server stays authoritative and its field errors are mapped back.
- **Permissions** arrive with the session (`/auth/me`) and hide what the user cannot use; the API enforces every
  rule again.
- **Money requests** keep their idempotency key while the outcome is unknown (network error, timeout, 5xx); the
  web till then offers only *Check again*, which repeats the request with the same key. Definitive rejections
  (4xx) end the attempt.
- **Printing** — after a sale the printable sheet shows the QR and the restaurant, never the voucher number or
  the value. The QR payload exists only in that response.

### Waiter app (`waiter-app/`, Flutter, Android and iPhone)

Scan a voucher's QR (camera) → `POST /presentments` → amount → `POST /vouchers/{id}/redemptions`. Every redemption
attempt is written encrypted to `PendingRedemptionStore` before its first request and removed only on a definitive
answer; unknown outcomes are resolved with `GET /vouchers/{id}/redemptions/{key}`. Managers and owners sell
printable vouchers (S20) and print them with the system print dialog. Details:
[waiter-app/README.md](../waiter-app/README.md).

## Scheduled and queued work

| Job | Schedule (`SCHEDULE_TIMEZONE`) | Purpose |
|---|---|---|
| `vouchers:expire` | daily 00:15 | Expire active vouchers whose last valid day has ended; balances are kept, blocked vouchers are skipped |
| `giftcard:verify-chains` | daily 02:30 | Recompute every hash chain and every voucher balance; e-mail `OPS_ALERT_EMAIL` on a problem |
| `queue:prune-failed --hours=720` | daily 03:30 | Housekeeping |
| `vouchers:notify-expiring` | daily 10:00 | One reminder per voucher with a balance, `VOUCHER_EXPIRING_NOTICE_DAYS` before expiry |
| `auth:clear-resets` | every 15 min | Remove expired reset tokens |
| `queue:monitor` | every 5 min (Redis queues) | Alert when a queue holds more than 500 jobs |
| `SendVoucherNotification`, `SendStaffInvitation`, `SendPasswordResetLink` | queued | Every e-mail is sent from the queue, with retries |
