# GiftCard Waiter

The native Android and iPhone app for restaurant staff: scan an NFC gift card, redeem its balance. Nothing else.
The design specification is [docs/design/waiter-app](../docs/design/waiter-app/README.md); this app implements it.

| | |
|---|---|
| Framework | Flutter 3.47 (Dart 3.13) |
| Platforms | Android 9+ (API 28), iOS 16+; iPad and tablets without NFC use QR and manual entry |
| Package / bundle id | `eu.tapredeem.waiter` (neutral id, spec 13 Q10) |
| API | `POST /auth/token` (device-bound token), `GET /app/config`, `GET /auth/me`, `POST /scan`, `POST /cards/{id}/redeem`, `GET /devices/current`, `POST /auth/logout` — see [docs/API.md](../docs/API.md) |
| Languages | German, English, Bosnian/Croatian/Serbian (from the master string table in spec 12) |

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
| `CARD_DOMAINS` | hosts of the card links `https://<host>/c/<uuid>` (comma-separated; the first one is used for Android App Links / NDEF intent filters) — must match the backend's `CARD_BASE_URL` |
| `APP_STORE_URL` | App Store listing opened by "Update required" (iOS production) |
| `PLAY_STORE_URL` | optional, defaults to the Play listing of the package |

If the server cannot be reached at launch (signed out), the app shows the reason — no internet, server not found
(DNS), server not running, no answer, certificate rejected, server error, wrong address — with the server address,
the technical detail and *Try again*; an invalid build configuration or unusable secure storage end on the same
screen. The app never stays on the launch screen.

The version is the GiftCard Pro platform version (`pubspec.yaml`, currently 1.4.2+2).

### Signing

- **Android:** create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword` (not committed). Without it a release build is signed with the debug key and Gradle prints a warning — never upload such a build.
- **iOS:** automatic signing; select the team in Xcode (or `DEVELOPMENT_TEAM` for `tool/release.sh ios-ipa`). The Associated Domains entitlement `applinks:$(CARD_DOMAIN)` takes its host from the environment: `tool/release.sh` writes `ios/Flutter/Environment.xcconfig` from `config/<environment>.json` (local runs: `localhost`). NFC entitlement: `TAG` only.

### Universal Links / App Links

The web app serves `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` from the variables `WAITER_IOS_APP_IDS`, `WAITER_ANDROID_PACKAGE` and `WAITER_ANDROID_CERT_SHA256` ([docs/ENVIRONMENT.md](../docs/ENVIRONMENT.md)). Set them before the first store release so card links open the app.

### Minimum version and maintenance notice

The platform admin sets **Minimum waiter app version (Android / iPhone)** and the maintenance notice under System settings. Older apps show "Update required"; the notice appears as a banner on the ready screen.

## Structure

| Path | Contents |
|---|---|
| `lib/app/` | bootstrap, root router (screens rendered from state), platform coordination (reader mode, keep awake, links, lifecycle) |
| `lib/core/api/` | HTTP client (request id per attempt, device id, bearer token, timeouts, error classes of spec 09 §9.3) and typed endpoints |
| `lib/core/state/` | `SessionController` (access, session, blocked states) and `LoopController` (the redeem loop and its idempotency rules, spec 02 §4.5 / 09 §4.4) |
| `lib/core/platform/` | NFC, haptics/sounds, biometrics, device facts — thin platform channels (`android/.../eu/tapredeem/waiter/*.kt`, `ios/Runner/Waiter*.swift`) |
| `lib/core/tokens/`, `lib/core/theme/` | design tokens (generated), theme, typography, icons, illustrations |
| `lib/core/format/`, `lib/core/l10n/`, `lib/l10n/` | money, dates, spoken forms, card numbers; strings (generated) |
| `lib/components/` | the component library of spec 05 |
| `lib/screens/` | S01–S17 |
| `tokens/waiter.tokens.json` | design tokens (source); `dart run tool/generate_tokens.dart` |
| `tool/import_strings.dart` | imports the master string table from spec 12 into `lib/l10n/*.arb` |
| `tool/synthesize_sounds.py`, `tool/render_brand_assets.py` | reproducible sounds, launcher icons and splash |

Generated files are never edited by hand; CI fails when they are out of date (`--check`).

## Tests

```bash
flutter analyze
flutter test                     # unit, component, screen and end-to-end journey tests
```

`test/support/app_harness.dart` wires the real controllers to a scripted backend, fake NFC and in-memory storage; `test/support/screen_harness.dart` pumps the whole app. Inside `testWidgets`, never `await` a controller or API future directly — act, then `settle(tester)`.

The backend side of the app's API is covered by `backend/tests/Feature/WaiterApp*Test.php` and, against a running stack, by `e2e/waiter-api.mjs`.

Not verifiable in CI: NFC with real cards, the iPhone system NFC sheet, biometrics and the iOS build (needs Xcode). Test them on the reference devices of spec 09 §11.3 before every release.
