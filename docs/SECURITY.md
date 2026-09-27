# Security

Security is the first design constraint of GiftCard Pro: a gift card is money, and every restaurant's data
must be invisible to every other restaurant. This document lists the threats and the concrete control that
addresses each one, with the code that implements it.

## Principles

1. **The card carries no value and no personal data** — only `https://…/c/{UUID v4}`.
2. **The server is the only source of truth** for balances; every change is atomic, locked, idempotent and ledgered.
3. **Deny by default** — every endpoint declares a permission; tenant scoping is automatic and enforced at several layers.
4. **Nothing is ever deleted** — revocation, soft deletes, append-only ledger and audit log.
5. **Defence in depth** — client checks are convenience only; the API re-validates everything.

## Threats and controls

| Threat | Controls | Code |
|---|---|---|
| **Cross-tenant access** | Global `RestaurantScope`; write guard (`TenantMismatchException`); tenant-scoped route binding (404 for foreign IDs); `RequireTenant`; tenant-scoped `exists` rules; service-level ownership assertions; foreign card scans rejected and logged without leaking the other restaurant | `Models/Concerns/BelongsToRestaurant`, `Http/Middleware/ResolveTenant`, `Services/GiftCards/*`, `tests/Feature/TenantIsolationTest` |
| **Privilege escalation** | Permission gates on every route (`can:`), role ranks (managers cannot create owners, nobody can assign `platform_admin`), no self-role-change, last-owner protection, token abilities ⊆ creator permissions | `Providers/AppServiceProvider::configureAuthorization`, `Services/Users/UserService`, `Services/ApiTokens/ApiTokenService` |
| **SQL injection** | Eloquent / query builder with bound parameters everywhere; `LIKE` wildcards escaped; sort columns whitelisted; driver-specific date bucket uses integer offsets only | `GiftCard::scopeSearch`, `CardIndexRequest::SORTS`, `ReportingTest` |
| **XSS** | React escapes by default; no `dangerouslySetInnerHTML`; strict CSP (`default-src 'self'`, `frame-ancestors 'none'`); session cookie is `httpOnly` (not readable by scripts); e-mail templates escape every placeholder and only substitute whitelisted keys | `next.config.ts`, `Services/Notifications/TemplateRenderer`, `NotificationTest` |
| **CSRF** | Sanctum SPA: `XSRF-TOKEN` double-submit + `SameSite=Lax` cookies; same-origin deployment with CORS explicitly disabled (`config/cors.php` → no cross-origin grants); API tokens never use cookies | `bootstrap/app.php (statefulApi)`, `lib/api/client.ts` |
| **Double spending / race conditions** | `SELECT … FOR UPDATE` on the card row inside a DB transaction for every balance change; deterministic lock order for transfers (no deadlocks); deadlock retries; `UNSIGNED` balance column; balance re-read from the locked row, never from the request | `GiftCardService`, `IdempotencyAndConcurrencyTest` — verified live with 20 concurrent requests on MariaDB |
| **Duplicate redemption / replayed requests** | Mandatory `Idempotency-Key` on money endpoints, unique per restaurant in the ledger; replays return the original transaction; key reuse with different payload → 409; UI keeps the key across network retries | `RequireIdempotencyKey`, `GiftCardService::idempotent` |
| **Replay of NFC reads** | NTAG 424 DNA: SUN message verified with AES-CMAC; 24-bit tap counter must strictly increase (atomic compare-and-set) | `Services/Nfc/*`, `CardScanService::verifyChip`, `CardScanTest` |
| **Card cloning** | NTAG21x: chip UID bound only after the written tag was read back and verified, mismatching UID rejected and audited (configurable); one chip cannot be bound to two usable cards (unique index `nfc_uid_active`, platform-wide); tags of other cards are refused before writing; every programming attempt logged (`nfc_write_attempts`); optional permanent tag lock; NTAG 424 DNA: cryptographic proof of the genuine chip (per-chip diversified keys) | `CardScanService`, `GiftCardService::bindNfcTag`, `NfcProgrammingService`, `NfcProgrammingTest`, [NFC.md](NFC.md) |
| **Guessing card tokens / numbers** | 122-bit random UUID v4 tokens; card numbers random (not sequential) with Luhn check; failed *and suspicious* lookups (UID mismatch, bad signature, replay) throttled per user and per IP; every attempt logged in `nfc_scans`; suspicious results also written to the application log as `warning` for alerting | `CardNumberGenerator`, `CardScanService`, `config/giftcard.php` |
| **Brute-force login** | Rate limit (5/min per e-mail+IP, 30/min per IP); account lock after 10 consecutive failures (atomic counter, logged as `warning`); constant-time comparison with a dummy hash for unknown e-mails; generic error messages; password reset answers identically for unknown addresses | `AuthController`, `PasswordController`, `AuthenticationTest` |
| **Abuse of a stolen card** | Block card (any staff with `cards.block`), velocity limit per card per hour, max single redemption, replacement issues a new token and permanently retires the old one | `GiftCardService`, `RestaurantSetting` |
| **Lost / stolen phone** | Devices are identified and can be revoked instantly; deactivating a user revokes all tokens and sessions; a browser session is pinned to the device it signed in on (a copied session cookie is useless on another device); sessions expire after inactivity; password change invalidates other sessions (`AuthenticateSession`) | `TrackDevice`, `DeviceService`, `UserService::deactivate` |
| **Leaked API token** | Tokens hashed (SHA-256) at rest, prefixed `gcp_` for secret scanning, shown once, scoped abilities, max lifetime, revocable, `last_used_at` / `last_used_ip` tracking | `ApiTokenService`, `PersonalAccessToken` |
| **Tampering / repudiation** | Immutable ledger & audit log (model-level guards), actor/device/IP/request id on every entry, microsecond timestamps, reversals as counter-entries instead of edits | `Models/Concerns/Immutable`, `AuditLogger` |
| **Data loss** | No hard deletes; RESTRICT foreign keys; nightly consistent dumps + off-site sync; server snapshots | [DEPLOYMENT.md](DEPLOYMENT.md#5-backups) |
| **Transport security** | HTTPS only (Caddy, automatic certificates, HSTS preload, HTTP/3), `Secure` cookies, `TrustProxies` limited to private network ranges (a client cannot spoof its IP via `X-Forwarded-For`) | `infra/caddy/Caddyfile` |
| **Clickjacking / MIME sniffing** | `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `nosniff` on API and web | `SecurityHeaders`, `next.config.ts` |
| **Cache leaks** | `Cache-Control: no-store, private` on every API response | `SecurityHeaders` |
| **CSV / formula injection** | Exported cells starting with `= + - @` are neutralised (plain numbers such as `-12,50` are left intact) | `Support/CsvSanitizer` |
| **Sensitive data in logs** | Audit values redact passwords/tokens/public tokens; personal data (customer names, e-mail, phone, notes, recipient names) is never copied into the audit log — only the fact that it changed; the public token never appears in API responses except to users allowed to write tags | `AuditLogger::REDACTED`, `GiftCardResource` |
| **Mass assignment** | Money/state columns are not fillable; only the service layer changes them with `forceFill` | `GiftCard::$fillable` |
| **Staff onboarding** | New users never receive a password: they get a one-time invitation link (72 h, separate broker from the 60-min password reset) and choose their own password | `StaffInvitation`, `UserService::invite`, `config/auth.php` |
| **Dependency vulnerabilities** | `composer audit` and `npm audit` in CI | `.github/workflows/ci.yml` |

## GDPR notes

- Customer data is optional and minimal (name, e-mail, phone, notes, marketing consent).
- **Right to erasure:** *Anonymize* removes all personal data of a customer (and recipient names on their cards)
  while keeping the financial ledger required for bookkeeping. E-mail addresses in the notification log are scrubbed too, and the audit log never contained them.
- **Data residency:** the reference deployment runs in Hetzner's German data centres.
- A data-processing agreement (AVV/DPA) with each restaurant is recommended; the platform is the processor.

## Legal note (Austria / EU)

Gift cards ("Gutscheine") in Austria are generally subject to the 30-year limitation period; shorter expiry
periods can be considered grossly disadvantageous to consumers unless objectively justified. The default
validity is configurable per restaurant (0 = no expiry). Restaurants should confirm their terms with their
legal advisor.

## Reporting a vulnerability

Please e-mail security@giftcardpro.at with details. We respond within 2 business days.
