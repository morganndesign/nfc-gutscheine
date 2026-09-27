# GiftCard Waiter — store release guide

Native app: `waiter-app/` (Flutter), package / bundle id **`eu.tapredeem.waiter`**, display name *GiftCard Waiter*.

## Version policy

The app carries the **GiftCard Pro platform version** (backend, dashboard and app share one number):
`pubspec.yaml → version: 1.4.2+2`.

| Part | Android | iOS | Rule |
|---|---|---|---|
| `1.4.1` | `versionName` | `CFBundleShortVersionString` | = platform release (1.4.2, 1.5.0, …) |
| `+1` | `versionCode` | `CFBundleVersion` | build number: +1 for **every** upload (Play and TestFlight reject a number twice); may keep increasing across versions |

Set the minimum app versions for old installs under *System settings* (platform admin) only after the new
version is live in both stores.

## Production configuration

`waiter-app/config/production.json` is the only place for release URLs (development and staging: `config/development.json`, `config/staging.json`, see [RUNNING_THE_PROJECT.md §3.0](../RUNNING_THE_PROJECT.md#30-environments--where-the-app-connects-to)):
`API_BASE_URL=https://app.giftcardpro.at/api/v1`, `CARD_DOMAINS=app.giftcardpro.at`, `APP_STORE_URL` (after the
App Store record exists), `PLAY_STORE_URL` (optional). Release builds refuse non-https API URLs; the card domain
also becomes the Android App Links / NFC intent-filter host and the iOS Associated Domains host (`tool/release.sh` writes
it to `ios/Flutter/Environment.xcconfig`; nothing is set in the Xcode project itself).

## Android

```bash
cd waiter-app
tool/release.sh android production   # needs android/key.properties (upload key, see below)
```

| Output | Path (relative to `waiter-app/`) | Use |
|---|---|---|
| APK | `build/dist/giftcard-waiter-production-<version>.apk` | install on test phones (`adb install`, or open the file on the phone) |
| AAB | `build/dist/giftcard-waiter-production-<version>.aab` | upload to Google Play |
| Dart symbols | `build/dist/giftcard-waiter-production-<version>-dart-symbols.zip` | keep per release: de-obfuscate Dart stack traces (`flutter symbolize`) |
| R8 mapping | `build/dist/giftcard-waiter-production-<version>-r8-mapping.txt.gz` | upload in Play Console (*App bundle explorer → Downloads*) for Java/Kotlin traces |

Both are signed with the **upload key** (Google Play App Signing re-signs installs from Play). The key, its
passwords and fingerprints are **not in the repository**: they are in `signing/` (`signing/ANDROID_SIGNING.md`),
which Git and Docker ignore. `android/key.properties` points to it (`storeFile=../../signing/giftcard-waiter-upload.jks`).

After the build, `scripts/collect-release.sh` copies all four outputs into `releases/<version>/android/` (see
[RUNNING_THE_PROJECT.md → Release](../RUNNING_THE_PROJECT.md#8-release)).

Built for 1.4.1 (1): target SDK 36 (Play requirement since 31 Aug 2026), min SDK 28, arm64-v8a /
armeabi-v7a / x86_64, R8 + resource shrinking, Dart obfuscation, no cleartext traffic, app data excluded from
cloud backup and device transfer. Download size from Play on an arm64 phone ≈ 9.8 MB.

### First Google Play release (needs your Play Console account)

1. *Create app* → name, default language, *App*, *Free*; accept the declarations.
2. *App signing*: keep the Google-generated key. Upload `app-release.aab` to **Internal testing** and add testers.
3. Copy the **app signing key SHA-256** (Play Console → *App signing*) into `WAITER_ANDROID_CERT_SHA256` on the
   server, after the upload key fingerprint (comma-separated). Check
   `https://app.giftcardpro.at/.well-known/assetlinks.json`.
4. Store listing: short and full description (DE/EN), `assets/store/play-store-icon-512.png`, **feature graphic 1024×500**,
   at least 2 phone screenshots (plus 7″/10″ tablet screenshots, the app installs on tablets).
5. *App content*: privacy policy URL, **App access** → "All or some functionality is restricted" with a review
   login (a waiter account of a review restaurant) **and** how to test without a physical card (manual card
   number of a review card with balance); Ads: none; content rating questionnaire; target audience 18+ (business
   app); **Data safety**: collected = e-mail address, user ID, device ID, purchase history (card redemptions) — for
   app functionality, encrypted in transit, not shared, no tracking; account deletion: accounts are created and
   deleted by the employer (restaurant), not in the app.
6. Promote internal → closed → production after the NFC release test (`docs/NFC-RELEASE-TEST.md`).

## iOS (TestFlight)

iOS builds need a Mac with Xcode (current version) and CocoaPods. The project is prepared:

| Setting | Value |
|---|---|
| Bundle id | `eu.tapredeem.waiter` (Runner, all configurations) |
| Version / build | from `pubspec.yaml` via `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` |
| Deployment target | iOS 16.0 (app and Pods) |
| Devices | iPhone and iPad (iPads without NFC use QR and manual entry) |
| Signing | **Automatic**; no team stored in the project — you select it in Xcode, or set `DEVELOPMENT_TEAM` for scripted builds (written to the uncommitted `ios/Flutter/Team.xcconfig`) |
| Entitlements | NFC tag reading `TAG` (the value `NDEF` is rejected by App Store Connect, ITMS-90778), Associated Domains `applinks:$(CARD_DOMAIN)` — the first `CARD_DOMAINS` host of the build's environment (production: `applinks:app.giftcardpro.at`) |
| Info.plist | NFC, camera and Face ID usage texts (DE/EN/BHS), ISO 7816 AID `D2760000850101` (NTAG 424 DNA), `ITSAppUsesNonExemptEncryption = NO` (HTTPS only → no export compliance documents), portrait on iPhone |
| Privacy manifest | `Runner/PrivacyInfo.xcprivacy`: no tracking; e-mail, user ID, device ID, purchase history for app functionality |
| App icon | single-size 1024 px, opaque, with dark and tinted variants; launch screen storyboard (light/dark) |
| Export | `ios/ExportOptions.plist` (App Store Connect, automatic signing, symbols uploaded) |

### Steps that need your Apple Developer account

1. **App ID:** Xcode creates it on first signing (automatic signing). NFC Tag Reading and Associated Domains are
   added from the entitlements; if Xcode reports a capability error, enable both for `eu.tapredeem.waiter` under
   developer.apple.com → Identifiers.
2. **App Store Connect → My Apps → +**: platform iOS, name, primary language, bundle id `eu.tapredeem.waiter`,
   SKU. Note the **Apple ID** (App Information) and put `https://apps.apple.com/app/id<Apple ID>` into
   `APP_STORE_URL` in `config/production.json`.
3. **Server:** `WAITER_IOS_APP_IDS=<Team ID>.eu.tapredeem.waiter` (Team ID: developer.apple.com → Membership).
   Check `https://app.giftcardpro.at/.well-known/apple-app-site-association`.
4. **Build and upload** on the Mac:
   ```bash
   cd waiter-app
   tool/release.sh ios production # production config + pod install, opens Xcode
   ```
   In Xcode: *Runner* target → *Signing & Capabilities* → select your **Team** (all configurations) →
   destination *Any iOS Device (arm64)* → **Product → Archive** → *Distribute App* → *App Store Connect* → *Upload*.
   Do **not** archive without running `tool/release.sh ios production` first: the production URLs come from the Flutter
   configuration it writes (an archive without it cannot start).
   Scripted alternative: `DEVELOPMENT_TEAM=<Team ID> tool/release.sh ios-ipa production`, then upload
   `build/ios/ipa/*.ipa` with the *Transporter* app.
5. **TestFlight:** after processing, answer the export compliance question (no non-exempt encryption — already
   declared in Info.plist), add internal testers.
6. **For App Review** (before external TestFlight or release): review login + review card number as for Play;
   note in *App Review Information* that the app is for restaurant staff and NFC is optional (QR / number work
   too); privacy labels matching the privacy manifest; privacy policy URL; iPhone 6.9″ and iPad 13″ screenshots.

The iOS code has been syntax-checked with the Swift 6.1 compiler; a full compile (UIKit, CoreNFC, CocoaPods)
only happens on the Mac. Report any Xcode error back before archiving.

## Release checklist

| Item | Android | iOS |
|---|---|---|
| Production API / card domain, https only | ✅ in the build (verified in the APK) | ✅ via `tool/release.sh ios production` |
| No dev URLs / debug flags | ✅ not debuggable, no cleartext, pseudo-localisation disabled in release | ✅ same Dart code; ATS default |
| NFC permission / entitlement | ✅ `NFC` (normal permission), NFC not required to install | ✅ `NFCReaderUsageDescription`, entitlement `TAG` |
| Camera | ✅ `CAMERA` (from the scanner plugin), camera not required | ✅ `NSCameraUsageDescription` |
| Biometrics | ✅ `USE_BIOMETRIC` | ✅ `NSFaceIDUsageDescription` |
| Deep links | ✅ App Links + NFC intent filter for `https://app.giftcardpro.at/c/*` | ✅ Associated Domains; ⏳ server `WAITER_IOS_APP_IDS` |
| assetlinks / AASA on server | ⏳ set `WAITER_ANDROID_CERT_SHA256` (upload + Play key) | ⏳ Team ID |
| Icons, splash | ✅ adaptive + monochrome icon, Android 12 splash | ✅ 1024 icon (opaque) + dark/tinted, launch screen |
| Version | ✅ 1.4.1 (1) | ✅ 1.4.1 (1) |
| Signing | ✅ upload key | ⏳ your team in Xcode |
| Privacy | ✅ backup exclusion; ⏳ Data safety form | ✅ privacy manifest; ⏳ privacy labels |
| Real devices | ⏳ `docs/NFC-RELEASE-TEST.md` + deep link and camera checks on phones | ⏳ same on iPhone (NFC sheet, Face ID, links) |
