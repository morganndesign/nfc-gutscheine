#!/usr/bin/env bash
# Builds GiftCard Waiter for one environment. The server addresses come from
# config/<environment>.json (nothing is hard-coded in the app); the version from
# pubspec.yaml (`version: 1.4.1+1` → 1.4.1, build 1). See RUNNING_THE_PROJECT.md.
#
#   tool/release.sh android  [environment]   signed APK (install on phones) + AAB (Google Play)
#   tool/release.sh ios      [environment]   macOS: prepare Xcode (config, CocoaPods) and open it → Archive
#   tool/release.sh ios-ipa  [environment]   macOS: build an .ipa (needs DEVELOPMENT_TEAM=<Team ID>)
#
# environment: production (default) | staging | development
#   development  http allowed, app id eu.tapredeem.waiter.dev ("GiftCard Waiter Dev"), server changeable in the app
#   staging      https only, app id eu.tapredeem.waiter.staging, server changeable in the app
#   production   https only, app id eu.tapredeem.waiter, server fixed
# A file config/<environment>.local.json, if present, is used instead of config/<environment>.json
# (for your own addresses, e.g. the LAN IP of your computer; not committed).
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-}"
ENVIRONMENT="${2:-production}"
case "$ENVIRONMENT" in development|staging|production) ;; *) echo "Unknown environment '$ENVIRONMENT' (development, staging, production)"; exit 1 ;; esac

CONFIG="config/$ENVIRONMENT.json"
[[ -f "config/$ENVIRONMENT.local.json" ]] && CONFIG="config/$ENVIRONMENT.local.json"
[[ -f "$CONFIG" ]] || { echo "$CONFIG not found"; exit 1; }

# Flat JSON, one "KEY": "value" per line.
value() { sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$CONFIG" | head -1; }
APP_ENV=$(value APP_ENV)
API_BASE_URL=$(value API_BASE_URL)
APP_STORE_URL=$(value APP_STORE_URL)

[[ "$APP_ENV" == "$ENVIRONMENT" ]] || { echo "$CONFIG: APP_ENV is '$APP_ENV', expected '$ENVIRONMENT'"; exit 1; }
[[ -n "$API_BASE_URL" ]] || { echo "$CONFIG: API_BASE_URL is empty — fill it in first"; exit 1; }
if [[ "$ENVIRONMENT" != development && "$API_BASE_URL" != https://* ]]; then
  echo "$CONFIG: API_BASE_URL must be https in $ENVIRONMENT builds"; exit 1
fi

VERSION=$(sed -n 's/^version: *//p' pubspec.yaml)
DEFINES=(--dart-define-from-file="$CONFIG")
# Dart symbols for crash de-obfuscation (keep them per release: `flutter symbolize`).
OBFUSCATE=(--obfuscate --split-debug-info=build/symbols)
DIST="build/dist"

echo "Environment: $ENVIRONMENT ($CONFIG) · API $API_BASE_URL · version $VERSION"

case "$TARGET" in
  android)
    if [[ ! -f android/key.properties ]]; then
      if [[ "$ENVIRONMENT" == development ]]; then
        echo "Note: android/key.properties missing — the development APK is signed with the debug key (fine for test phones)."
      else
        echo "android/key.properties missing — see signing/ANDROID_SIGNING.md"; exit 1
      fi
    fi
    flutter pub get
    flutter build apk --release "${DEFINES[@]}" "${OBFUSCATE[@]}"
    flutter build appbundle --release "${DEFINES[@]}" "${OBFUSCATE[@]}"
    mkdir -p "$DIST"
    APK="$DIST/giftcard-waiter-$ENVIRONMENT-$VERSION.apk"
    AAB="$DIST/giftcard-waiter-$ENVIRONMENT-$VERSION.aab"
    cp build/app/outputs/flutter-apk/app-release.apk "$APK"
    cp build/app/outputs/bundle/release/app-release.aab "$AAB"
    # Crash symbols of exactly this build (the next build overwrites build/symbols and the R8 mapping).
    rm -f "$DIST/giftcard-waiter-$ENVIRONMENT-$VERSION-dart-symbols.zip"
    (cd build && zip -qr "dist/giftcard-waiter-$ENVIRONMENT-$VERSION-dart-symbols.zip" symbols)
    if [[ -f build/app/outputs/mapping/release/mapping.txt ]]; then
      gzip -9c build/app/outputs/mapping/release/mapping.txt > "$DIST/giftcard-waiter-$ENVIRONMENT-$VERSION-r8-mapping.txt.gz"
    fi
    echo
    echo "APK (install on phones):  $(pwd)/$APK"
    echo "AAB (Google Play):        $(pwd)/$AAB"
    echo "Dart symbols:             $(pwd)/build/symbols"
    if [[ "$ENVIRONMENT" == production ]]; then echo "File the release: ../scripts/collect-release.sh"; fi
    ;;
  ios|ios-ipa)
    [[ "$(uname)" == "Darwin" ]] || { echo "iOS builds need macOS with Xcode"; exit 1; }
    if [[ "$ENVIRONMENT" == production && -z "$APP_STORE_URL" ]]; then
      echo "Note: APP_STORE_URL is empty — 'Update required' cannot open the App Store on iPhone."
    fi
    flutter pub get
    if [[ "$TARGET" == "ios" ]]; then
      # Writes ios/Flutter/Generated.xcconfig (version, dart-defines) and runs pod install;
      # an Xcode Archive then builds exactly this configuration.
      flutter build ios --release --config-only "${DEFINES[@]}" "${OBFUSCATE[@]}"
      open ios/Runner.xcworkspace
      echo "Xcode: select your team (Runner → Signing & Capabilities), Product → Archive, Distribute App → App Store Connect."
    else
      [[ -n "${DEVELOPMENT_TEAM:-}" ]] || { echo "Set DEVELOPMENT_TEAM=<Apple Team ID>"; exit 1; }
      printf 'DEVELOPMENT_TEAM=%s\n' "$DEVELOPMENT_TEAM" > ios/Flutter/Team.xcconfig
      flutter build ipa --release "${DEFINES[@]}" "${OBFUSCATE[@]}" \
        --export-options-plist=ios/ExportOptions.plist
      echo "IPA: $(ls "$(pwd)"/build/ios/ipa/*.ipa) — upload with Transporter or: xcrun altool --upload-app -f <ipa> -t ios --apiKey … --apiIssuer …"
    fi
    ;;
  *)
    sed -n '2,16p' "$0"; exit 1 ;;
esac
