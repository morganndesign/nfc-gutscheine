# GiftCard Waiter — store release guide

Native app: `waiter-app/` (Flutter), package / bundle id **`eu.tapredeem.waiter`**, display name *GiftCard Waiter*.
The app scans voucher QR codes with the camera, redeems them, and lets managers and owners sell and print
vouchers. It has no NFC code, no NFC permission or entitlement and opens no links.

## Version policy

The app carries the **GiftCard Pro platform version** (backend, dashboard and app share one number):
`pubspec.yaml → version: 2.0.0+4`.

| Part | Android | iOS | Rule |
|---|---|---|---|
| `2.0.0` | `versionName` | `CFBundleShortVersionString` | = platform version |
| `+4` | `versionCode` | `CFBundleVersion` | build number of local builds: +1 for every upload made from a local build (stores reject a number twice) |

TestFlight uploads from CI use the build number `1000 + <run number of the TestFlight workflow>`, so they always
grow and never collide with local builds.

Set the minimum app versions for old installs under *System settings* (platform admin) only after the new version
is available in both stores.

## Production configuration

`waiter-app/config/production.json` is the only place for release URLs (development and staging:
`config/development.json`, `config/staging.json`, see
[RUNNING_THE_PROJECT.md §3.0](../RUNNING_THE_PROJECT.md#30-environments--where-the-app-connects-to)):
`API_BASE_URL=https://app.giftcardpro.at/api/v1`, `APP_STORE_URL` (after the App Store record exists),
`PLAY_STORE_URL` (optional). Release builds refuse non-https API URLs.

## Android

```bash
cd waiter-app
tool/release.sh android production   # needs android/key.properties (upload key, see below)
```

| Output | Path (relative to `waiter-app/`) | Use |
|---|---|---|
| APK | `build/dist/giftcard-waiter-production-<version>.apk` | install on test phones (`adb install`) |
| AAB | `build/dist/giftcard-waiter-production-<version>.aab` | upload to Google Play |
| Dart symbols | `build/dist/giftcard-waiter-production-<version>-dart-symbols.zip` | keep per release: de-obfuscate Dart stack traces (`flutter symbolize`) |
| R8 mapping | `build/dist/giftcard-waiter-production-<version>-r8-mapping.txt.gz` | upload in Play Console (*App bundle explorer → Downloads*) |

Both are signed with the **upload key** (Google Play App Signing re-signs installs from Play). The key, its
passwords and fingerprints are **not in the repository**: they are in `signing/` (`signing/ANDROID_SIGNING.md`),
which Git and Docker ignore. `android/key.properties` points to it (`storeFile=../../signing/giftcard-waiter-upload.jks`).

After the build, `scripts/collect-release.sh` copies all four outputs into `releases/<version>/android/` (see
[RUNNING_THE_PROJECT.md → Release](../RUNNING_THE_PROJECT.md#8-release)).

Build settings: target SDK 36, min SDK 28, R8 + resource shrinking, Dart obfuscation, no cleartext traffic, app data
excluded from cloud backup and device transfer. Permissions: `INTERNET`, `VIBRATE`, `CAMERA` (from the scanner
plugin; the camera is not required to install, so phones without one can still sell vouchers), `USE_BIOMETRIC` (from
the biometrics plugin). The ML Kit barcode model ships with the app. Flutter deep linking is off; the manifest has
only the launcher intent filter.

### First Google Play release (needs your Play Console account)

1. *Create app* → name, default language, *App*, *Free*; accept the declarations.
2. *App signing*: keep the Google-generated key. Upload the AAB to **Internal testing** and add testers.
3. Store listing: short and full description (DE/EN), `assets/store/play-store-icon-512.png`, **feature graphic
   1024×500**, at least 2 phone screenshots (plus 7″/10″ tablet screenshots, the app installs on tablets).
4. *App content*: privacy policy URL; **App access** → "All or some functionality is restricted" with a review login
   (a waiter account of a review restaurant) and a printed or on-screen voucher QR of a review voucher with a
   balance; Ads: none; content rating questionnaire; target audience 18+ (business app); **Data safety**: collected =
   e-mail address, user ID, device ID, purchase history (voucher redemptions and sales) — for app functionality,
   encrypted in transit, not shared, no tracking; account deletion: accounts are created and deleted by the employer
   (restaurant), not in the app.
5. Promote internal → closed → production after the device checks of the release checklist below.

## iOS

### TestFlight from CI

`.github/workflows/testflight.yml` builds, signs and uploads the app to TestFlight on every push to `main` that
touches `waiter-app/**` (or the workflow itself), and on demand (*Actions → TestFlight → Run workflow*). It runs on a
macOS runner:

1. `flutter build ios --release --config-only` with `config/production.json`, Dart obfuscation and the build number
   `1000 + run number`;
2. `xcodebuild archive` with automatic signing through the App Store Connect API key (Xcode manages certificates and
   profiles itself: no `.p12` or provisioning profile is stored anywhere);
3. export with `ios/ExportOptions.plist` (App Store Connect, automatic signing, symbols uploaded);
4. `xcrun altool --upload-app` to TestFlight;
5. the Dart symbols are kept as a workflow artifact (`dart-symbols-<run number>`, 400 days); the API key file is
   deleted at the end.

It needs these **repository secrets** (GitHub → *Settings → Secrets and variables → Actions*):

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Apple Developer Team ID (10 characters; developer.apple.com → Membership) |
| `APP_STORE_CONNECT_KEY_ID` | Key ID of an App Store Connect API key (App Store Connect → Users and Access → Integrations, role *App Manager*) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID shown on the same page |
| `APP_STORE_CONNECT_KEY_P8` | The downloaded `AuthKey_<KEY_ID>.p8`, base64-encoded (`base64 -i AuthKey_XXXX.p8`) |

Without `APP_STORE_CONNECT_KEY_P8` the job prints a notice and skips every step, so forks and pull requests stay
green. The CI workflow (`ci.yml`) additionally builds the app for iOS without signing on every push and pull
request, so iOS build problems appear before a merge.

### Project settings

| Setting | Value |
|---|---|
| Bundle id | `eu.tapredeem.waiter` (Runner, all configurations) |
| Version / build | from `pubspec.yaml` via `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` (CI overrides the build number) |
| Deployment target | iOS 16.0 (app and Pods) |
| Devices | iPhone and iPad |
| Signing | **Automatic**; no team stored in the project — CI passes `DEVELOPMENT_TEAM`, local builds select it in Xcode or write it to the uncommitted `ios/Flutter/Team.xcconfig` |
| Entitlements | NFC tag reading (`com.apple.developer.nfc.readersession.formats` = TAG); ISO 7816 AID `D2760000850101` in Info.plist; no Associated Domains |
| Info.plist | camera and Face ID usage texts (localised DE/EN/BS/HR/SR), `ITSAppUsesNonExemptEncryption = NO` (HTTPS only), `FlutterDeepLinkingEnabled = NO` |
| Privacy manifest | `Runner/PrivacyInfo.xcprivacy`: no tracking; e-mail, user ID, device ID, purchase history for app functionality |
| App icon | single-size 1024 px, opaque, with dark and tinted variants; launch screen storyboard (light/dark) |
| Export | `ios/ExportOptions.plist` |

### First release (needs your Apple Developer account)

1. **App ID:** created on the first signed build (automatic signing). It needs the **NFC Tag Reading** capability
   (developer.apple.com → Identifiers → `eu.tapredeem.waiter`); Xcode enables it from the entitlements, check it there
   if signing fails.
2. **App Store Connect → Apps → +**: platform iOS, name, primary language, bundle id `eu.tapredeem.waiter`, SKU.
   Note the **Apple ID** (App Information) and put `https://apps.apple.com/app/id<Apple ID>` into `APP_STORE_URL`
   in `config/production.json`.
3. **API key and secrets:** create the App Store Connect API key and set the four secrets above. The next push to
   `main` that changes the app (or *Run workflow*) uploads a build.
4. **TestFlight:** after processing, add internal testers.
5. **For App Review** (before external TestFlight or release): review login and a review voucher QR as for Play;
   note in *App Review Information* that the app is for restaurant staff; privacy labels matching the privacy
   manifest; privacy policy URL; iPhone 6.9″ and iPad 13″ screenshots.

### Local build on a Mac (alternative)

```bash
cd waiter-app
tool/release.sh ios production                                   # writes the configuration, opens Xcode
DEVELOPMENT_TEAM=<Team ID> tool/release.sh ios-ipa production     # scripted .ipa → upload with Transporter
```

In Xcode: *Runner* → *Signing & Capabilities* → your **Team** → destination *Any iOS Device (arm64)* →
**Product → Archive** → *Distribute App* → *App Store Connect* → *Upload*. Do not archive without running
`tool/release.sh ios production` first: the production configuration comes from the Flutter configuration it
writes. Raise the build number in `pubspec.yaml` for every local upload.

## Release checklist

| Item | Android | iOS |
|---|---|---|
| Production API, https only | `config/production.json` via `tool/release.sh` | same file, via CI or `tool/release.sh` |
| No dev URLs / debug flags | not debuggable, no cleartext, pseudo-localisation off in release | same Dart code; ATS default |
| Camera | `CAMERA`, not required to install | `NSCameraUsageDescription` |
| Biometrics | `USE_BIOMETRIC` | `NSFaceIDUsageDescription` |
| Links / NFC | none | none (no entitlements) |
| Icons, splash | adaptive + monochrome icon, Android 12 splash | 1024 icon (opaque) + dark/tinted, launch screen |
| Version | `2.0.0+4` from `pubspec.yaml` | `2.0.0`, build `1000 + run number` from CI |
| Signing | upload key from `signing/` | App Store Connect API key (GitHub secrets) |
| Privacy | backup exclusion; Data safety form | privacy manifest; privacy labels |
| Real devices | camera scan of printed and on-screen QR codes, redemption, lost-answer recovery, selling and printing (system print dialog), biometrics | the same on an iPhone and an iPad (AirPrint) |
