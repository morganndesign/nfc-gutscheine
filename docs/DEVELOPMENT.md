# Development guide

> Step-by-step commands for every component (backend, dashboard, waiter app, database, release) are in
> [RUNNING_THE_PROJECT.md](../RUNNING_THE_PROJECT.md); this page adds background and details.

## Conventions

**PHP**
- `declare(strict_types=1)` everywhere, typed properties/params/returns, `final` classes by default.
- Laravel Pint (`laravel` preset + strict comparison) — `vendor/bin/pint`.
- Larastan level 8 — `vendor/bin/phpstan analyse`.
- Controllers stay thin; **every state change goes through a service** and receives an `Actor`.
- Business-rule failures throw a `DomainException` subclass with a stable `errorCode()` — never return error arrays.
- Money is always `int` cents. Never `float`.
- Tenant-owned models use `BelongsToRestaurant`; financial history uses `Immutable` and `HashChained` (write
  payments → ledger → audit log in that order inside one transaction).
- Never delete business data: use a status, `revoked_at`, `anonymized_at`, a soft delete or a new correcting entry.
- Secrets never appear in logs, audit values or exceptions (`#[SensitiveParameter]` on credential arguments).

**TypeScript**
- `strict` mode; no `any`. API types live in `src/lib/api/types.ts` and mirror the Laravel resources.
- Server state only via React Query hooks in `src/lib/api/hooks.ts`; invalidate by key prefix.
- Forms: React Hook Form + Zod; map server `VALIDATION_FAILED` errors back to fields.
- UI primitives from `src/components/ui` (shadcn/ui). Add new ones with `npx shadcn@latest add <name>`.
- Prettier (`npm run format`), ESLint (`npm run lint`), `npm run typecheck`.

## Testing

```bash
cd backend
php artisan test                                  # all tests, SQLite in memory
php artisan test --filter=VoucherLifecycleTest
php artisan test tests/Feature/Abuse              # the abuse suite
```

| Suite | Covers |
|---|---|
| `Unit/AesCmacTest`, `Unit/Ntag424SunVerifierTest` | RFC 4493 and NXP AN12196 vectors of the SUN library |
| `Unit/VoucherNumberTest`, `CsvSanitizerTest`, `EnvironmentGuardTest` | helpers |
| `Feature/Abuse/PresentmentAbuseTest` | no redemption without a presentment; expired, reused, other user, other device, other voucher, other restaurant, revoked QR, wrong kind, `live_auth` unavailable, voucher number as a credential, lockout per user and device, outcome by key, waiter token limits |
| `Feature/Abuse/PaymentAbuseTest` | sales and reloads without a valid payment, complimentary rules |
| `Feature/Abuse/IntegrityTest` | the verifier finds a changed amount, a deleted row, a changed payment method and a balance that differs from its ledger |
| `Feature/Abuse/AccessControlAbuseTest` | remembered sign-in only on a known device, no tokens for platform administrators, password reset and change revoke tokens, uniform reset answers, invitations survive a reset request, reset mail outage |
| `Feature/Abuse/RemovedPathsTest` | every removed endpoint answers 404, every debit route needs a presentment, no removed concept remains in the code (`public_token`, NTAG21x, card programming, `/scan`, transfers, replacement, card links) |
| `Feature/VoucherLifecycleTest` | sale, redemption, reload, block, expire, reinstate, reverse, history; direct `UPDATE`/`DELETE` on ledger, payments and audit log are rejected by the database |
| `Feature/IdempotencyAndConcurrencyTest` | replays, key conflicts, re-check after the lock, velocity |
| `Feature/AuthenticationTest`, `HardeningTest` | sign-in, uniform failures, lockout, remembered sign-in, token revocation, session pinning |
| `Feature/TenantIsolationTest`, `PermissionsTest` | no data leaks between restaurants; role matrix |
| `Feature/WaiterAppTokenTest`, `WaiterAppIssuingTest`, `WaiterAppConfigTest` | device tokens, allowed requests, selling in the app, start-up configuration |
| `Feature/PlatformAdmin*Test`, `RestaurantManagementTest`, `OwnerInvitationTest`, `StaffManagementTest`, `InvitationEmailLocalizationTest`, `PlatformTestMailTest` | platform administration, invitations, mail diagnostics |
| `Feature/SettingsAndApiTokensTest`, `ReportingTest`, `NotificationTest`, `PilotReadinessTest`, `QueueBacklogAlertTest` | settings, tokens, dashboard, exports, guest e-mails, alerts |

### Testing against MySQL

Row locks and the MySQL triggers behave differently from SQLite; CI runs every test on both.

```bash
docker compose -f docker-compose.dev.yml up -d mysql
mysql -h127.0.0.1 -uroot -proot -e "CREATE DATABASE giftcard_test"
sed -e 's#<env name="DB_CONNECTION" value="sqlite"/>#<env name="DB_CONNECTION" value="mysql"/><env name="DB_HOST" value="127.0.0.1"/><env name="DB_USERNAME" value="root"/><env name="DB_PASSWORD" value="root"/>#' \
    -e 's#<env name="DB_DATABASE" value=":memory:"/>#<env name="DB_DATABASE" value="giftcard_test"/>#' phpunit.xml > phpunit.mysql.xml
php artisan test --configuration=phpunit.mysql.xml
```

CI also runs `php artisan migrate:fresh --seed` on MySQL followed by `php artisan giftcard:verify-chains`, so the
demo data's hash chains and balances are verified after a real JSON round trip.

### Concurrency smoke test

Start `PHP_CLI_SERVER_WORKERS=10 php artisan serve` against MySQL and fire parallel redemptions at one voucher,
each with its own presentment and idempotency key: exactly `floor(balance / amount)` succeed, the rest answer
`INSUFFICIENT_BALANCE`, and the ledger sum equals the balance. Ten requests sharing one idempotency key give one
`201` and nine `200` replays; two redemptions with the same presentment book at most once.

### End-to-end tests

[`e2e/`](../e2e/README.md): `pilot-journey.mjs` plays the first day of a restaurant in real browsers (onboarding,
invitations, sale with the printable sheet, redemption by QR on a phone, reload, block, export, axe accessibility
scan); `waiter-api.mjs` plays the waiter app's API calls; `platform-admin.mjs` covers platform administration.

### Static analysis

`vendor/bin/phpstan analyse` (Larastan, level 8) and `vendor/bin/pint --test` must be clean.

### CI (`.github/workflows/ci.yml`)

| Job | Runs |
|---|---|
| Backend | Pint, Larastan, tests on SQLite, tests on MySQL 8.4, `migrate:fresh --seed` + `giftcard:verify-chains` on MySQL, `composer audit` |
| Dashboard | lint, typecheck, unit tests, build, `npm audit --audit-level=high` |
| Waiter app | generated files up to date, `flutter analyze`, `flutter test`, release APK |
| Waiter app iOS | unsigned release build on macOS |
| Docker | `docker-compose.coolify.yml` validation and a build of every service |

`.github/workflows/testflight.yml` uploads the app to TestFlight on merges to `main`
([MOBILE_RELEASE.md](MOBILE_RELEASE.md#testflight-from-ci)).

## Adding a feature — checklist

1. **Permission**: add a case to `App\Enums\Permission`, grant it in `RoleSlug::defaultPermissions()`, re-run
   `php artisan db:seed --class=RolesAndPermissionsSeeder`, add it to `Permission` in `types.ts`.
2. **Schema**: a new migration with UUID primary key, `restaurant_id` + `BelongsToRestaurant` if tenant-owned;
   financial history append-only (trigger + `Immutable`), hash-chained where it records money.
3. **Service** method with `Actor`, transaction, row lock where money is involved, audit log entry.
4. **Request** (validation, `existsInTenant()` for foreign keys), **Resource**, **Controller**, route with `can:`.
   If the waiter app calls it, add the method and path to `EnforceDeviceToken::ALLOWED`.
5. **Tests**: happy path, permission denied, other tenant → 404, invalid input, and an abuse test for every rule
   that forbids something (`tests/Feature/Abuse/`).
6. **Frontend**: type → hook → component; guard with `can()`.
7. **Docs**: [API.md](API.md) (endpoints and error codes), [DATABASE.md](DATABASE.md) if the schema changed.

## Useful commands

```bash
php artisan route:list --path=api
php artisan vouchers:expire                  # run the expiry job now
php artisan vouchers:notify-expiring
php artisan giftcard:verify-chains           # verify hash chains and balances
php artisan platform:create-admin me@example.com
php artisan migrate:fresh --seed             # rebuild the local database with demo data
```

## Internationalisation

The dashboard is in English; money, dates and numbers use the restaurant's locale (`de-AT` by default). The
printable voucher sheet is available in German, English and Bosnian/Croatian/Serbian. Guest e-mails exist in
German and English (editable per restaurant); invitation e-mails follow the restaurant's language. The waiter app is
in German, English and Bosnian/Croatian/Serbian (master string table in `docs/design/waiter-app/`).
