# Folder structure (code level)

File-level map of the source code. For the project folders (releases, signing, assets, scripts) and what may be
committed or deleted, see [PROJECT_STRUCTURE.md](../PROJECT_STRUCTURE.md).

```
GiftCardPro/
├── backend/                         Laravel 12 API
│   ├── app/
│   │   ├── Console/Commands/        giftcards:expire, giftcards:notify-expiring, platform:create-admin, giftcard:nfc-keys
│   │   ├── Data/                    DTOs: IssueGiftCardData, ScanInput, TransactionResult
│   │   ├── Enums/                   GiftCardStatus, TransactionType, Permission, RoleSlug, NfcTagType, ScanMethod, …
│   │   ├── Events/                  GiftCardIssued, GiftCardRedeemed, GiftCardReloaded (after-commit)
│   │   ├── Exceptions/Domain/       Typed business-rule exceptions with stable error codes
│   │   ├── Http/
│   │   │   ├── Controllers/Api/V1/  Thin REST controllers (+ Admin/ for the platform)
│   │   │   ├── Middleware/          ResolveTenant, RequireTenant, TrackDevice, RequireIdempotencyKey, SecurityHeaders, AssignRequestId
│   │   │   ├── Requests/            FormRequest validation per endpoint
│   │   │   └── Resources/           JSON representations (GiftCard, ScannedCard, Transaction, …)
│   │   ├── Jobs/                    SendCardNotification
│   │   ├── Listeners/               QueueCardNotifications
│   │   ├── Mail/                    TemplatedMail
│   │   ├── Models/                  Eloquent models (+ Concerns/BelongsToRestaurant, Concerns/Immutable, Scopes/RestaurantScope)
│   │   ├── Providers/               Gate::before permission resolution, rate limiters, Sanctum, bindings
│   │   ├── Services/
│   │   │   ├── GiftCards/           GiftCardService, CardScanService, CardHistoryService, CardNumberGenerator, CardUrlBuilder, QrCodeService, NfcUid
│   │   │   ├── Nfc/                 AesCmac, Ntag424SunVerifier, SunMessage
│   │   │   ├── Audit/ Dashboard/ Exports/ Users/ Restaurants/ Devices/ ApiTokens/ Notifications/
│   │   └── Support/                 Actor, Money, CardNumber, CsvSanitizer, Tenancy/TenantContext
│   ├── bootstrap/app.php            Middleware pipeline & JSON error rendering
│   ├── config/giftcard.php          Product configuration
│   ├── database/
│   │   ├── factories/               Restaurant, User, Customer, Device, GiftCard
│   │   ├── migrations/              UUID-keyed schema
│   │   └── seeders/                 Roles & permissions, templates, system settings, DemoSeeder
│   ├── resources/views/mail/        Branded e-mail layout
│   ├── routes/api.php               REST API v1
│   ├── routes/console.php           Scheduler
│   ├── tests/Unit, tests/Feature    113 tests
│   └── Dockerfile
├── dashboard/                        Next.js 15 web app
│   ├── src/app/                     Routes (see ARCHITECTURE.md)
│   ├── src/components/              ui/ (shadcn) · layout/ · cards/ · waiter/ · charts/ · dashboard/ · settings/ · common/
│   ├── src/hooks/                   use-mobile, use-debounce, use-capabilities
│   ├── src/lib/                     api client, hooks, types, auth, nfc, money, format, regional, audit, guest-copy
│   ├── public/                      manifest, icon
│   └── Dockerfile
├── e2e/                             Browser acceptance test: the pilot restaurant's first day
├── infra/
│   ├── caddy/Caddyfile              TLS + routing
│   ├── docker/php/                  php.ini, FPM pool, entrypoint
│   └── scripts/                     deploy.sh, backup.sh
├── .github/workflows/               ci.yml, deploy.yml
├── docker-compose.yml               Production stack
├── docker-compose.dev.yml           Local MySQL / Redis / Mailpit
└── docs/                          Guides; docs/screenshots/ holds the current UI
```
