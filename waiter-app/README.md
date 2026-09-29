# GiftCard Waiter

The native Android and iPhone app for restaurant staff: scan a voucher's QR code and redeem its balance; managers
and owners also sell printable vouchers. Android and iPhone have the same features.
The design specification is [docs/design/waiter-app](../docs/design/waiter-app/README.md); ADR-002
([docs/implementation/v2-implementation-plan.md](../docs/implementation/v2-implementation-plan.md)) takes precedence
where they differ.

| | |
|---|---|
| Framework | Flutter 3.47 (Dart 3.13) |
| Platforms | Android 9+ (API 28), iOS 16+, tablets and iPad |
| Package / bundle id | `eu.tapredeem.waiter` (neutral id, spec 13 Q10) |
| API | `POST /auth/token` (device-bound token), `GET /app/config`, `GET /auth/me`, `POST /presentments`, `POST /vouchers/{id}/redemptions`, `GET /vouchers/{id}/redemptions/{key}`, `POST /vouchers` (sell), `GET /devices/current`, `POST /auth/logout` — see [docs/API.md](../docs/API.md) |
| Languages | German, English, Bosnian/Croatian/Serbian (from the master string table in spec 12) |

## How redeeming works

1. **Scan** (S12): only a voucher QR (`GCPV1.` + 43 characters) is sent; anything else is refused on the phone.
2. **Presentment**: `POST /presentments` proves the voucher is here, now. The answer is single use, bound to this
   waiter, this phone and this voucher, and valid for 60 s (`expires_in`, counted down from receipt). After that S07
   shows *Scan again*; the typed amount is kept.
3. **Redeem** (S07): `POST /vouchers/{id}/redemptions` with the presentment and an `Idempotency-Key`.
4. **Unknown outcomes** (audit M1, M2, M6): the attempt — key, voucher, amount — is written to protected storage
   *before* the first request leaves the phone and is removed only on a definitive answer. Retries always reuse the
   key. After *Cancel*, a lost answer or an app restart, the outcome is asked with
   `GET /vouchers/{id}/redemptions/{key}`, never by sending the debit again; while an attempt is unresolved its
   voucher accepts no other amount. "Not booked" counts only once the request can no longer be running on the server
   (60 s after it was sent). A gateway answer (401, 403, 429) after an unanswered request never closes an attempt.

## Selling (S20)

Managers and owners (`vouchers.sell`): value (within the restaurant's limits) → how the guest paid (cash, card
terminal with receipt number, bank transfer with reference, complimentary with a reason — owners only) → optional
guest e-mail → `POST /vouchers` (`form: printable`). The QR is returned once and printed with the system print dialog
(AirPrint / Android print service) as an A6 sheet in the restaurant's language, without voucher number or value.
Leaving before printing asks first. A retry after a lost answer reuses the key: the server returns the same sale with
a fresh QR (while the guest can still be at the counter, 15 minutes, same waiter and phone; otherwise the screen
says to block the voucher in the dashboard and sell a new one). While a sale is unconfirmed, only an answer of the
sale itself closes it, and leaving asks first.

## Build and run

**Environments:** development (your computer), staging, production. The server address is never written in the
code — it comes from `config/<environment>.json` at build time ([config/README.md](config/README.md)); development
and staging builds can also switch server in the app (long-press the DEV / STAGING corner badge). Step-by-step:
[RUNNING_THE_PROJECT.md → Waiter app](../RUNNING_THE_PROJECT.md#3-waiter-app-giftcard-waiter-flutter--waiter-app).

```bash
flutter pub get
flutter run --dart-define-from-file=config/development.json        # emulator → backend on your computer
tool/release.sh android development                                 # APK/AAB for test phones (app "GiftCard Waiter Dev")
tool/release.sh android production                                  # store build (signed with the upload key)
tool/release.sh ios production                                      # Mac: Xcode Archive → TestFlight
```

| Define (in `config/*.json`) | Meaning |
|---|---|
| `APP_ENV` | `development` · `staging` · `production` — http allowed only in development; development/staging get their own app id (`.dev` / `.staging`) and a corner badge |
| `API_BASE_URL` | API root ending in `/api/v1` |
| `APP_STORE_URL` | App Store listing opened by "Update required" (iOS production) |
| `PLAY_STORE_URL` | optional, defaults to the Play listing of the package |

If the server cannot be reached at launch (signed out), the app shows the reason — no internet, server not found
(DNS), server not running, no answer, certificate rejected, server error, wrong address — with the server address,
the technical detail and *Try again*; an invalid build configuration or unusable secure storage end on the same
screen. The app never stays on the launch screen.

The version is the GiftCard Pro platform version (`pubspec.yaml`, currently 2.0.0+4).

### Signing

- **Android:** create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword` (not committed). Without it a release build is signed with the debug key and Gradle prints a warning — never upload such a build.
- **iOS:** automatic signing; select the team in Xcode (or `DEVELOPMENT_TEAM` for `tool/release.sh ios-ipa`). The app has no special entitlements; the camera and Face ID usage texts come from spec 12 §5.21.

### Minimum version and maintenance notice

The platform admin sets **Minimum waiter app version (Android / iPhone)** and the maintenance notice under System settings. Older apps show "Update required"; the notice appears as a banner on the ready screen.

## Structure

| Path | Contents |
|---|---|
| `lib/app/` | bootstrap, root router (screens rendered from state), keep-awake and lifecycle |
| `lib/core/api/` | HTTP client (request id per attempt, device id, bearer token, timeouts, error classes of spec 09 §9.3) and typed endpoints |
| `lib/core/state/` | `SessionController` (access, session, blocked states) and `LoopController` (the redeem loop and its money-safety rules) |
| `lib/core/storage/` | settings, Recent and the unresolved redemption attempts (`PendingRedemptionStore`), encrypted at rest |
| `lib/core/sale/` | `SaleController` (S20) |
| `lib/core/platform/` | haptics/sounds, biometrics, device facts, printing — thin platform channels (`android/.../eu/tapredeem/waiter/*.kt`, `ios/Runner/Waiter*.swift`) |
| `lib/core/tokens/`, `lib/core/theme/` | design tokens (generated), theme, typography, icons, illustrations |
| `lib/core/format/`, `lib/core/l10n/`, `lib/l10n/` | money, dates, spoken forms, voucher numbers; strings (generated) |
| `lib/components/` | the component library of spec 05 |
| `lib/screens/` | S01–S20 |
| `tokens/waiter.tokens.json` | design tokens (source); `dart run tool/generate_tokens.dart` |
| `tool/import_strings.dart` | imports the master string table from spec 12 into `lib/l10n/*.arb` |
| `tool/synthesize_sounds.py`, `tool/render_brand_assets.py` | reproducible sounds, launcher icons and splash |

Generated files are never edited by hand; CI fails when they are out of date (`--check`).

## Tests

```bash
flutter analyze
flutter test                     # unit, component, screen and end-to-end journey tests
```

`test/support/app_harness.dart` wires the real controllers to a scripted backend, a fake printer and in-memory storage; `test/support/screen_harness.dart` pumps the whole app. Inside `testWidgets`, never `await` a controller or API future directly — act, then `settle(tester)`.

The backend side of the app's API is covered by `backend/tests/Feature/WaiterApp*Test.php` and `backend/tests/Feature/Abuse/PresentmentAbuseTest.php` and, against a running stack, by `e2e/waiter-api.mjs`.

CI builds the iOS app unsigned on macOS, and `.github/workflows/testflight.yml` uploads signed builds to TestFlight once the App Store Connect key is set as repository secrets ([docs/MOBILE_RELEASE.md](../docs/MOBILE_RELEASE.md)). Not verifiable in CI: the camera with real printed and on-screen QR codes, printing on real printers and biometrics. Test them on the reference devices of spec 09 §11.3 before every release.
