# Development guide

> Step-by-step commands for every component (backend, dashboard, waiter app, NFC, database, release) are in
> [RUNNING_THE_PROJECT.md](../RUNNING_THE_PROJECT.md); this page adds background and details.

## Conventions

**PHP**
- `declare(strict_types=1)` everywhere, typed properties/params/returns, `final` classes by default.
- Laravel Pint (`laravel` preset + strict comparison) — `vendor/bin/pint`.
- Larastan level 6 — `vendor/bin/phpstan analyse`.
- Controllers stay thin; **all state changes go through a service** and receive an `Actor`.
- Business-rule failures throw a `DomainException` subclass with a stable `errorCode()` — never return error arrays.
- Money is always `int` cents. Never `float`.
- Tenant-owned models use `BelongsToRestaurant`; append-only models use `Immutable`.
- Never delete: add a status/`revoked_at`/`anonymized_at` instead.

**TypeScript**
- `strict` mode; no `any`. API types live in `src/lib/api/types.ts` and must mirror the Laravel resources.
- Server state only via React Query hooks in `src/lib/api/hooks.ts`; invalidate by key prefix.
- Forms: React Hook Form + Zod; map server `VALIDATION_FAILED` errors back to fields.
- UI primitives from `src/components/ui` (shadcn/ui). Add new ones with `npx shadcn@latest add <name>`.
- Prettier (`npm run format`), ESLint (`npm run lint`), `npm run typecheck`.

## Testing

```bash
cd backend
php artisan test                           # all 113 tests (SQLite in-memory)
php artisan test --filter=GiftCardLifecycleTest
```

| Suite | Covers |
|---|---|
| `Unit/AesCmacTest` | RFC 4493 vectors |
| `Unit/Ntag424SunVerifierTest` | NXP AN12196 SUN vectors, negatives, key diversification |
| `Unit/CardNumberTest`, `CardUrlBuilderTest`, `CsvSanitizerTest` | helpers |
| `Feature/AuthenticationTest` | login, lockout, rate limits, suspended tenants, password change |
| `Feature/TenantIsolationTest` | no data leaks between restaurants |
| `Feature/PermissionsTest` | role matrix, revoked devices |
| `Feature/GiftCardLifecycleTest` | issue, redeem, reload, block, activate, reverse, transfer, replace, expire, history, immutability, QR |
| `Feature/IdempotencyAndConcurrencyTest` | replays, key conflicts, stale-model overdraw, velocity |
| `Feature/CardScanTest` | NFC/manual scan, throttling, UID binding, NTAG 424 SUN + replay |
| `Feature/PlatformAdminTest`, `StaffManagementTest`, `SettingsAndApiTokensTest`, `ReportingTest`, `NotificationTest` | admin, team & invitations, settings, tokens, dashboard, exports, GDPR, e-mails |
| `Feature/PilotReadinessTest` | owner KPIs (liability + number of cards), device names, replacement notes, readable CSV names |
| `Feature/HardeningTest` | regressions from the v1.1 audit: timezone-correct expiry, explicit no-expiry, replacement of inactive cards, replay counter on re-bind, optional idempotency on card creation, session↔device pinning, closed restaurants, exactly-once e-mails, no PII in audit log, health check, CORS off, CSV decimal comma |

### Testing against MySQL

```bash
docker compose -f docker-compose.dev.yml up -d mysql
mysql -h127.0.0.1 -uroot -proot -e "CREATE DATABASE giftcard_test"
sed -e 's#<env name="DB_CONNECTION" value="sqlite"/>#<env name="DB_CONNECTION" value="mysql"/><env name="DB_HOST" value="127.0.0.1"/><env name="DB_USERNAME" value="root"/><env name="DB_PASSWORD" value="root"/>#' \
    -e 's#<env name="DB_DATABASE" value=":memory:"/>#<env name="DB_DATABASE" value="giftcard_test"/>#' phpunit.xml > phpunit.mysql.xml
php artisan test --configuration=phpunit.mysql.xml
```

### Concurrency smoke test

Start `PHP_CLI_SERVER_WORKERS=10 php artisan serve` against MySQL, create an API token with `cards.redeem`,
and fire parallel requests with different idempotency keys at one card: exactly `floor(balance / amount)`
requests must succeed, the rest must return `INSUFFICIENT_BALANCE`, and `SUM(ledger) == balance`.
The same run should also cover concurrent reloads (cap at `max_card_balance`), concurrent replacements (exactly one
wins), redemptions racing a replacement, ten requests sharing one idempotency key (one `201`, nine `200` replays)
and opposing transfers between two cards (no deadlock).

### Browser acceptance test

[`e2e/pilot-journey.mjs`](../e2e/README.md) plays the first day of a restaurant in real browsers (onboarding,
invitations, sale, waiter redemption on a phone in < 5 s, reload, replacement, export, axe accessibility scan).
Run it before every release.

### Static analysis

`vendor/bin/phpstan analyse` (Larastan, level 8) and `vendor/bin/pint --test` must be clean.

## Adding a feature — checklist

1. **Permission**: add a case to `App\Enums\Permission`, grant it in `RoleSlug::defaultPermissions()`,
   re-run `php artisan db:seed --class=RolesAndPermissionsSeeder`, add it to `Permission` in `types.ts`.
2. **Schema**: new migration with UUID PK, `restaurant_id` + `BelongsToRestaurant` if tenant-owned, soft deletes.
3. **Service** method with `Actor`, transaction, audit log entry.
4. **Request** (validation, `existsInTenant()` for foreign keys), **Resource**, **Controller**, route with `can:`.
5. **Tests**: happy path, permission denied, other tenant → 404, invalid input.
6. **Frontend**: type → hook → component; guard with `can()`.
7. **Docs**: API.md (+ DATABASE.md if schema changed).

## Useful commands

```bash
php artisan route:list --path=api
php artisan giftcards:expire                 # run expiration now
php artisan giftcards:notify-expiring
php artisan platform:create-admin me@example.com
php artisan giftcard:nfc-keys
php artisan migrate:fresh --seed             # reset local DB with demo data
```

## Internationalisation

The UI is in English; money, dates and numbers use the restaurant's locale (`de-AT` by default). Customer
e-mails and the public balance page are available in German and English (templates are editable per
restaurant). To translate the dashboard, introduce `next-intl` and move strings into message catalogs —
components already avoid string concatenation for formatted values.
