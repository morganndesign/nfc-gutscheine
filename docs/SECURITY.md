# Security

A voucher is money, and every restaurant's data must be invisible to every other restaurant. This document lists
the threats and the control that addresses each one, with the code that implements it.

## Principles

1. **Spending needs proof of presence.** Every debit consumes a presentment: single use, 60 seconds, bound to user,
   device, restaurant and voucher. A voucher number is never a credential.
2. **The server is the only source of truth** for balances; every change is atomic, locked, idempotent and recorded
   in the ledger.
3. **Financial history is immutable.** Ledger, payments and audit log are append-only (database triggers) and
   hash-chained; a nightly job verifies every chain and every balance.
4. **Deny by default.** Every endpoint declares a permission; tenant scoping is automatic and enforced at several
   layers; tokens are limited further by their abilities and, for the waiter app, by method and path.
5. **Defence in depth.** Client checks are convenience only; the API validates everything again.

## Threats and controls

| Threat | Controls | Code |
|---|---|---|
| **Spending without the voucher** | Every redemption consumes a verified, unexpired `spend` presentment of that voucher, made by the same user on the same device, in the same database transaction (lock order presentment → voucher). Presentments are single use (`verified → consumed`), valid 60 s, and a ledger entry references at most one (`UNIQUE`). Spending rules by kind: digital vouchers only with a QR method, card vouchers only with `live_auth`, which has no verifier yet. Every refused presentment is audited (`presentment.failed`, `presentment.rejected`) | `Services/Presentments/*`, `Services/Vouchers/VoucherService::redeem`, `tests/Feature/Abuse/PresentmentAbuseTest` |
| **Guessing or copying a voucher** | The printable QR carries a 256-bit random secret (`GCPV1.` + base64url); only its SHA-256 hash is stored, the payload is returned once at the sale and never logged. It is not a URL, so it never lands in web server logs or browser histories. Voucher numbers are random, Luhn-checked and never accepted as a credential. Failed presentments are limited per restaurant, user and device (10 per 5 min), never per IP | `Services/Media/PrintableQrService`, `Services/Vouchers/VoucherNumberGenerator`, `PresentmentService` |
| **Cross-tenant access** | Global `RestaurantScope`; write guard (`TenantMismatchException`); tenant-scoped route binding (404 for foreign ids); `RequireTenant`; tenant-scoped `exists` rules; ownership assertions in the services; a QR of another restaurant is "not recognised", like an unknown one | `Models/Concerns/BelongsToRestaurant`, `Http/Middleware/ResolveTenant`, `RequireTenant`, `tests/Feature/TenantIsolationTest` |
| **Privilege escalation** | Permission gates on every route (`can:`); role ranks (managers cannot create owners, nobody can assign `platform_admin`); no self role change; last-owner protection; token abilities ⊆ the creator's permissions; platform administrators never act inside a restaurant and cannot create or use tokens | `Providers/AppServiceProvider`, `Services/Users/UserService`, `Services/ApiTokens/ApiTokenService`, `tests/Feature/Abuse/AccessControlAbuseTest` |
| **Stolen waiter app token** | Bound to the phone's `X-Device-Id` (fingerprint per restaurant); limited to the seven method + path pairs the app uses; stops at once when the device is revoked; revoked on sign-out, password reset or change; 30-day rolling expiry | `Http/Middleware/EnforceDeviceToken`, `Services/Auth/DeviceTokenService`, `tests/Feature/WaiterAppTokenTest` |
| **Stolen "remember me" cookie** | A session restored from the cookie is accepted only on an active device this person already used; platform administrators always sign in explicitly; revoking a device rotates the remember token of its users; "remember me" is off by default | `Http/Middleware/BindRememberedSignIn`, `Services/Auth/AccessRevoker`, `Services/Devices/DeviceService::revoke` |
| **Compromised password** | A password reset or change revokes every token (device and integration) and rotates the remember token; other browser sessions end through `AuthenticateSession` | `Services/Auth/AccessRevoker`, `PasswordController` |
| **Brute-force sign-in** | Rate limit (5/min per e-mail + IP, 30/min per IP); lock after 10 consecutive failures (atomic counter, logged as `warning`); a locked account, a wrong password and an unknown address answer the same `422` with the same timing (the password is always hashed) | `Services/Auth/CredentialVerifier`, `tests/Feature/AuthenticationTest` |
| **Account enumeration and token confusion** | `forgot-password` answers identically for every address and sends from the queue; every reset failure answers the same message; invitation and reset tokens live in separate tables (`invitation_tokens`, `password_reset_tokens`) with separate lifetimes (72 h, 60 min), so a reset request can never replace an invitation; accounts with a pending invitation get no reset link | `PasswordController`, `Jobs/SendPasswordResetLink`, `config/auth.php` |
| **Double spending / race conditions** | `SELECT … FOR UPDATE` on the voucher row inside a DB transaction for every balance change; deadlock retries; `UNSIGNED` balance columns; the balance is re-read from the locked row, never taken from the request | `VoucherService`, `tests/Feature/IdempotencyAndConcurrencyTest` (also run on MySQL in CI) |
| **Duplicate booking / lost answers** | Mandatory `Idempotency-Key` on sale, redemption and reload, unique per restaurant in the ledger; the key is checked again after the row lock, so a retry that waited replays the first result; the same key for another request → 409. A till whose answer was lost asks `GET /vouchers/{id}/redemptions/{key}` instead of sending the debit again, and never shows "nothing was booked" while the outcome is unknown | `Http/Middleware/RequireIdempotencyKey`, `VoucherService::idempotent`, `VoucherActionController::redemptionOutcome`, waiter app `PendingRedemptionStore` |
| **Tampering / repudiation** | Ledger, payments and audit log: database triggers reject `UPDATE` and `DELETE`, the model layer refuses them earlier (`IMMUTABLE_RECORD`); each row is linked into a per-restaurant SHA-256 hash chain; `giftcard:verify-chains` recomputes every chain and every balance nightly and e-mails `OPS_ALERT_EMAIL` on any difference. Corrections are new entries (reversal, reinstatement); actor, device, IP and request id on every entry; microsecond timestamps | `database/migrations/…000007_make_financial_history_append_only.php`, `Models/Concerns/Immutable`, `Models/Concerns/HashChained`, `Services/Integrity/ChainVerifier`, `tests/Feature/Abuse/IntegrityTest` |
| **Money without payment** | Every sale and reload records the payment that funded it (`cash`, `card_terminal` + receipt reference, `bank_transfer` + reference, `complimentary` + reason); complimentary needs `vouchers.sell_complimentary` (owners) | `VoucherService::recordPayment`, `tests/Feature/Abuse/PaymentAbuseTest` |
| **Losing a guest's money** | No default expiry; a restaurant validity is at least 36 months; expiry keeps the balance and an owner can reinstate the voucher; manual expiry is owner-only with a reason; blocked vouchers are skipped by the nightly job | `VoucherService::expire`, `reinstate`, `expireDue` |
| **Abuse of a voucher** | Block (with reason); limits per redemption, per voucher per day and redemptions per voucher per hour, checked under the row lock; platform ceilings for every restaurant limit | `VoucherService::assertDebitLimits`, `assertVelocity`, `config/giftcard.php → limits` |
| **Lost / stolen phone** | Devices are identified and can be revoked instantly; deactivating a user revokes tokens and sessions; a browser session is pinned to its device; sessions expire after inactivity | `TrackDevice`, `DeviceService`, `UserService::deactivate` |
| **Leaked integration token** | Tokens hashed (SHA-256) at rest, prefixed `gcp_` for secret scanning, shown once, scoped abilities, maximum lifetime, revocable by the owner and by platform administrators, `last_used_at` / `last_used_ip` | `ApiTokenService`, `Admin/ApiTokenController` |
| **SQL injection** | Eloquent / query builder with bound parameters; `LIKE` wildcards escaped; sort columns whitelisted; date buckets use integer offsets only | `Voucher::scopeSearch`, `VoucherIndexRequest::SORTS`, `tests/Feature/ReportingTest` |
| **XSS** | React escapes by default; strict CSP (`default-src 'self'`, `frame-ancestors 'none'`); httpOnly session cookie; e-mail templates escape every placeholder and accept only whitelisted keys | `dashboard/next.config.ts`, `Services/Notifications/TemplateRenderer`, `tests/Feature/NotificationTest` |
| **CSRF** | Sanctum SPA: `XSRF-TOKEN` double submit + `SameSite=Lax`; same-origin deployment, no cross-origin grants; tokens never use cookies | `bootstrap/app.php`, `dashboard/src/lib/api/client.ts` |
| **Slow requests exhausting the API** | Mail is always sent from the queue (`MAIL_TIMEOUT=10`); php-fpm ends any request after 30 s (`request_terminate_timeout`) | `Jobs/*`, `infra/docker/php/www.conf` |
| **Secrets in logs** | Reset and invitation tokens travel in the URL fragment (never sent to a server); the gateway's access and error logs drop the query parameters `token`, `email`, `e`, `m` and the `Cookie`, `Authorization`, `X-Device-Id`, `Idempotency-Key` and `Set-Cookie` headers; Docker log rotation on every service (10 MB × 5); audit values redact passwords, tokens and secret hashes; guest personal data is never copied into the audit log, only the fact that it changed | `infra/docker/gateway/Caddyfile`, `docker-compose.coolify.yml`, `Services/Audit/AuditLogger` |
| **Data loss** | Restaurants, users, devices and customers are soft-deleted; `RESTRICT` foreign keys from financial tables; daily consistent dumps with triggers (`backup` service) plus an off-site copy | [DEPLOYMENT.md](DEPLOYMENT.md#backups) |
| **Transport security** | HTTPS only (Coolify proxy with automatic certificates; gateway and API add HSTS), `Secure` cookies, only private network ranges may set `X-Forwarded-*`, no service publishes a host port | `infra/docker/gateway/Caddyfile`, `bootstrap/app.php`, `docker-compose.coolify.yml` |
| **Clickjacking / MIME sniffing / caching** | `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `nosniff`; `Cache-Control: no-store, private` on every API response except `/app/config` | `Http/Middleware/SecurityHeaders`, `next.config.ts` |
| **CSV / formula injection** | Exported cells starting with `= + - @` are neutralised (plain numbers such as `-12,50` stay intact) | `Support/CsvSanitizer` |
| **Mass assignment** | Money and status columns are not fillable; only the service layer changes them with `forceFill` | `Models/Voucher` |
| **Dependency vulnerabilities** | `composer audit` and `npm audit --audit-level=high` in CI | `.github/workflows/ci.yml` |

Every rule above that forbids something has an abuse test that tries the forbidden path (`backend/tests/Feature/Abuse/`),
including every removed path (`RemovedPathsTest`).

## Keys and secrets

- Signing keys (Android upload key and its passwords) live in `signing/`, which is never committed (`.gitignore`,
  `.dockerignore`). iOS signing uses an App Store Connect API key stored only as GitHub secrets.
- Production configuration lives only in the Coolify resource's environment variables; the repository holds no
  `.env`.
- Card keys for NTAG 424 DNA are designed to live in a hardware security module behind the crypto service
  ([NFC.md](NFC.md)); no card key is part of the production configuration.

## GDPR notes

- Customer data is optional and minimal (name, e-mail, phone, notes, marketing consent).
- **Right to erasure:** *Anonymize* removes a customer's personal data, the recipient names on their vouchers and
  their address in the notification log, while keeping the financial ledger required for bookkeeping. The audit log
  never contained it.
- Guest e-mails are receipts (amount, restaurant, date, payment method); they never carry a QR payload, voucher number, link, token or balance, so a forwarded or leaked e-mail cannot be used to pay.
- **Data residency:** the deployment guide places the server in a German data centre (Hetzner).
- A data-processing agreement (AVV/DPA) with each restaurant is recommended; the platform is the processor.

## Legal note (Austria / EU)

Vouchers ("Gutscheine") in Austria are generally subject to the 30-year limitation period; shorter validity periods
can be considered grossly disadvantageous to consumers unless objectively justified. Vouchers have no expiry unless
the restaurant sets a validity of at least 36 months, and an expired voucher keeps its balance. Restaurants should
confirm their terms with their legal advisor.

## Reporting a vulnerability

Please e-mail security@giftcardpro.at with details. We respond within 2 business days.
