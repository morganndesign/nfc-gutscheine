# Folder structure (code level)

File-level map of the source code. For the project folders (releases, signing, assets, scripts) and what may be
committed or deleted, see [PROJECT_STRUCTURE.md](../PROJECT_STRUCTURE.md).

```
GiftCardPro/
├── backend/                         Laravel 12 API
│   ├── app/
│   │   ├── Console/Commands/        vouchers:expire, vouchers:notify-expiring, giftcard:verify-chains, platform:create-admin
│   │   ├── Data/                    DTOs: IssueVoucherData, PaymentData, SaleResult, TransactionResult, PrintableSecret
│   │   ├── Enums/                   VoucherKind, VoucherStatus, TransactionType, PaymentMethod, PresentmentMethod/Purpose/Status,
│   │   │                            MediumType/Role/Status, Permission, RoleSlug, DeviceStatus, UserStatus, RestaurantStatus
│   │   ├── Events/                  VoucherIssued, VoucherRedeemed, VoucherReloaded (after commit)
│   │   ├── Exceptions/Domain/       Typed business-rule exceptions with stable error codes
│   │   ├── Http/
│   │   │   ├── Controllers/Api/V1/  Thin REST controllers: Voucher, VoucherAction, Presentment, Transaction, … (+ Admin/)
│   │   │   ├── Middleware/          AssignRequestId, BindRememberedSignIn, EnforceDeviceToken, ResolveTenant, RequireTenant,
│   │   │   │                        TrackDevice, RequireIdempotencyKey, SecurityHeaders
│   │   │   ├── Requests/            FormRequest validation per endpoint (Vouchers/, Auth/, Settings/, Users/, Admin/, …)
│   │   │   └── Resources/           JSON representations (Voucher, PresentedVoucher, Presentment, Payment, Transaction, …)
│   │   ├── Jobs/                    SendVoucherNotification, SendStaffInvitation, SendPasswordResetLink (every e-mail is queued)
│   │   ├── Listeners/               QueueVoucherNotifications, RecordTokenUsage, AlertOnQueueBacklog, CheckApplicationHealth
│   │   ├── Mail/, Notifications/    TemplatedMail, StaffInvitation
│   │   ├── Models/                  Eloquent models (+ Concerns/BelongsToRestaurant, Immutable, HashChained; Scopes/RestaurantScope)
│   │   ├── Providers/               Gate::before permission resolution, rate limiters, Sanctum, presentment verifiers, bindings
│   │   ├── Services/
│   │   │   ├── Vouchers/            VoucherService, VoucherHistoryService, VoucherNumberGenerator, QrCodeService
│   │   │   ├── Presentments/        PresentmentService, PresentmentVerifier, PrintableQrVerifier
│   │   │   ├── Media/               PrintableQrService
│   │   │   ├── Integrity/           ChainVerifier
│   │   │   ├── Auth/                CredentialVerifier, DeviceTokenService, AccessRevoker
│   │   │   ├── Nfc/                 AesCmac, Ntag424SunVerifier, SunMessage (library, no endpoint uses it)
│   │   │   └── Audit/ Dashboard/ Exports/ Users/ Restaurants/ Devices/ ApiTokens/ Notifications/
│   │   └── Support/                 Actor, Money, VoucherNumber, HashChain, CsvSanitizer, AppVersion, EnvironmentGuard, Tenancy/TenantContext
│   ├── bootstrap/app.php            Middleware pipeline and JSON error rendering
│   ├── config/giftcard.php          Product configuration (security, limits, notifications)
│   ├── database/
│   │   ├── factories/               Restaurant, User, Customer, Device, Voucher
│   │   ├── migrations/              Schema 000001–000007 (000007: append-only triggers)
│   │   └── seeders/                 Roles and permissions, templates, system settings, DemoSeeder
│   ├── lang/                        Invitation e-mail texts (de, en)
│   ├── resources/views/mail/        E-mail layout
│   ├── routes/api.php               REST API v1
│   ├── routes/console.php           Scheduler
│   ├── tests/Unit, tests/Feature    PHPUnit; tests/Feature/Abuse is the abuse suite
│   └── Dockerfile
├── dashboard/                       Next.js 15 web app
│   ├── src/app/                     Routes (see ARCHITECTURE.md): (auth)/, (app)/, waiter/
│   ├── src/components/              ui/ (shadcn) · layout/ · vouchers/ · waiter/ · charts/ · dashboard/ · settings/ · admin/ · common/
│   ├── src/hooks/                   use-mobile, use-debounce, use-capabilities
│   ├── src/lib/                     api client, hooks, types, auth, outcome, payment, guest-copy, money, format, regional, audit
│   ├── public/                      manifest, icon
│   └── Dockerfile
├── waiter-app/                      GiftCard Waiter (Flutter): see waiter-app/README.md → Structure
│   ├── lib/app/, lib/core/          bootstrap, router; api, state, storage (PendingRedemptionStore), sale, platform, theme, l10n
│   ├── lib/components/, lib/screens/  component library; screens S01–S20
│   ├── config/                      development.json, staging.json, production.json
│   └── tool/release.sh              builds for one environment
├── e2e/                             pilot-journey.mjs, waiter-api.mjs, platform-admin.mjs
├── infra/
│   ├── docker/gateway/              Caddyfile + Dockerfile: routes /api, /sanctum, /up → Laravel, rest → Next.js; log redaction
│   └── docker/php/                  php.ini, FPM pool (30 s request limit), entrypoint (roles app/worker/scheduler; migrations)
├── .github/workflows/               ci.yml (tests, builds, unsigned iOS build), testflight.yml (TestFlight upload)
├── docker-compose.coolify.yml       Production stack (Coolify, built from source)
├── .env.production.example          Reference of the Coolify environment variables
├── docker-compose.dev.yml           Local MySQL / Redis / Mailpit
└── docs/                            Guides, architecture, implementation plan, reports
```
