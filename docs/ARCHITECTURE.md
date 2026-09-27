# Architecture

## System overview

```
┌──────────────┐   HTTPS (one origin)   ┌─────────┐  /api /sanctum /up   ┌──────────────────────────┐
│ Browser      │ ─────────────────────▶ │ Gateway │ ───────────────────▶ │ Laravel 12 (PHP-FPM)     │
│ · Dashboard  │                        │         │                      │  HTTP → Services → Models│
│ · Waiter app │ ◀── Next.js pages ──── │ (Caddy) │ ──── everything else ─▶ Next.js 15 (standalone)  │
│ · Balance pg │                        └─────────┘                      └──────┬──────────┬────────┘
└──────┬───────┘                                                               │          │
       │ Web NFC / camera / iOS link                                    MySQL 8.4    Redis 7
 ┌─────┴─────┐                                                   (ledger, tenants) (sessions, cache,
 │ NFC card  │  stores only https://…/c/{uuid-v4}                                    queues, locks)
 └───────────┘                                          queue worker ─┘   scheduler ─┘
```

**Why one origin?** Sanctum's cookie-based SPA authentication is the most secure option for a browser app:
httpOnly session cookie (not readable by JavaScript → immune to token theft via XSS), SameSite=Lax plus
CSRF tokens. Serving the SPA and the API from the same host removes CORS entirely.

## Backend layers

```
Http/Middleware   AssignRequestId → (Sanctum) → ResolveTenant → RequireTenant → throttle → bindings → TrackDevice → can:
Http/Requests     input validation only (FormRequest)
Http/Controllers  thin: parse request → call service → return Resource
Services          business rules, transactions, locking, auditing   ← the only place state changes happen
Models            persistence, casts, relations, tenant scope, immutability guards
Data / Support    DTOs (IssueGiftCardData, ScanInput, TransactionResult), Actor, Money, CardNumber, TenantContext
```

- **Service layer** — `GiftCardService` owns every balance/status change; `CardScanService` owns lookup and
  anti-fraud; `UserService`, `RestaurantService`, `DeviceService`, `ApiTokenService`, `DashboardService`,
  `CardNotificationService`, `AuditLogger`.
- **No repository layer.** Eloquent already is a repository/data-mapper hybrid; wrapping it would add
  indirection without value. Query logic that is reused lives in model scopes (`search`, `outstanding`,
  `forRestaurant`).
- **Actor** — every service call receives an `Actor` (user, device, IP, user agent, request id) so ledger
  and audit entries are attributable in HTTP, queue and console contexts alike.
- **Domain exceptions** — each business rule violation is a typed exception with a stable error code
  (`INSUFFICIENT_BALANCE`, `CARD_BLOCKED`, …) rendered as JSON by `bootstrap/app.php`.
- **Events** (`GiftCardIssued/Reloaded/Redeemed`) implement `ShouldDispatchAfterCommit`: listeners (e-mails)
  only run once the money movement is durable.

## Multi-tenancy

Single database, shared schema, `restaurant_id` on every tenant-owned table.

1. `ResolveTenant` middleware binds the authenticated user's restaurant to the request-scoped
   `TenantContext` (platform admins may opt in via `X-Restaurant-Id`).
2. `BelongsToRestaurant` trait adds `RestaurantScope` (all reads filtered), stamps `restaurant_id` on create,
   and throws `TenantMismatchException` if code ever tries to write a row into another tenant or move a row.
3. Route model binding resolves `{card}`, `{customer}`, `{device}`, `{transaction}` through the scope →
   foreign IDs are indistinguishable from non-existent ones (404).
4. `RequireTenant` refuses restaurant endpoints when no tenant is bound, so a missing tenant can never
   widen a query to all restaurants.
5. Validation rules use `existsInTenant()` so foreign IDs fail validation.
6. Services re-assert ownership (`assertOwnedByTenant`) — defence in depth.

Users are resolved before a tenant exists (authentication), so the `User` model is not globally scoped;
every staff query filters by `restaurant_id` explicitly and `{user}` binding is tenant-constrained.

## Money flow (redeem)

```
POST /cards/{id}/redeem  (Idempotency-Key: uuid)
 └ RequireIdempotencyKey
 └ GiftCardService::redeem
     ├ existing transaction with this key?  → return it (replayed: true) or 409 if the request differs
     └ DB::transaction (3 attempts on deadlock)
         ├ SELECT … FROM gift_cards WHERE id = ? FOR UPDATE      ← serialises concurrent redemptions
         ├ checks: status, expiry, balance, max single redemption, partial allowed, velocity limit
         ├ INSERT gift_card_transactions (amount -x, balance_before, balance_after, key UNIQUE per restaurant)
         ├ UPDATE gift_cards SET balance, total_redeemed, status (redeemed at 0)
         ├ INSERT audit_logs
         └ COMMIT → GiftCardRedeemed (after commit) → queued e-mail if balance crossed the low threshold
```

Invariants (asserted by tests):

- `gift_cards.balance == SUM(gift_card_transactions.amount)` for every card.
- `balance` is `UNSIGNED` — the database itself rejects negative balances.
- Ledger rows are never updated (except `reversed_at`) and never deleted.
- Money is stored as integer minor units (cents); no floating point anywhere.

## Card lifecycle

```
            issue(activate=false)            activate
   ┌────────────▶ inactive ─────────────────────┐
issue ─────────────────────────────────────────▶ active ◀──── reload ──── redeemed
                                                 │  └── redeem to 0 ─────────▲
                           block ◀──────────────┤
                   blocked ── unblock ──────────▶┘
   any open state ── expire (manual / scheduler) ──▶ expired   (balance written off)
   any open state ── replace (lost card) ──────────▶ replaced  (balance moved to new card)
```

## Frontend

```
src/app
 ├ (auth)/login, forgot-password, reset-password
 ├ (app)/…            dashboard, cards, transactions, customers, team, devices, audit, settings, account, admin/*
 ├ waiter/            mobile terminal (tap → amount → redeem)
 ├ c/[token]/         URL on the card: staff → terminal with card opened; guests → public balance
 └ print/cards/[id]   ID-1 card print layout with QR
src/lib
 ├ api/client.ts      fetch wrapper (CSRF, device id, idempotency, typed ApiError)
 ├ api/hooks.ts       React Query hooks per domain (cache keys, invalidation)
 ├ api/types.ts       types mirroring the Laravel API resources
 ├ auth.tsx           session provider, permission checks (`can()`)
 ├ nfc.ts             Web NFC read/write/lock wrapper
 └ money.ts, format.ts
src/components
 ├ ui/                shadcn/ui primitives (Radix)
 ├ layout/            sidebar shell, guards, acting banner
 ├ cards/, waiter/, charts/, settings/, common/
```

- **Server state** lives only in React Query; mutations invalidate by key prefix (`["cards"]`, `["dashboard"]`…).
- **Forms** use React Hook Form + Zod (client validation mirrors server rules; the server stays authoritative
  and its field errors are mapped back onto the form).
- **Permissions** are delivered with the session (`/auth/me`) and hide UI the user cannot use. Every rule
  is enforced again by the API.
- **Idempotency in the UI** — each money dialog holds a key for its current attempt. Network failures keep
  the key (retry cannot double charge); definitive rejections (4xx) rotate it.

### Charts

Charts use Recharts via shadcn's `ChartContainer`. Series colours come from a validated categorical palette
(`--chart-1` blue for sold, `--chart-2` orange for redeemed) with separate dark-mode steps; status breakdown
uses a single hue (magnitude, not identity) with text labels, so identity never depends on colour alone.

## Scheduled & queued work

| Job | Schedule | Purpose |
|---|---|---|
| `giftcards:expire` | daily 00:15 | Expire due cards per restaurant, write off balance via ledger |
| `giftcards:notify-expiring` | daily 09:00 | Queue one reminder per card N days before expiry |
| `queue:prune-failed` | daily | Housekeeping |
| `auth:clear-resets` | every 15 min | Remove stale password reset tokens |
| `SendCardNotification` | queued (`notifications`) | Unique per card/template/transaction, 5 tries with back-off |
