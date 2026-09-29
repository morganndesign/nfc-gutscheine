#!/usr/bin/env bash
# Collects the outputs of a finished release into releases/<version>/ and points releases/latest at it.
# Does not build anything and does not touch source code. See RUNNING_THE_PROJECT.md → "Release".
#
#   scripts/collect-release.sh            version from waiter-app/pubspec.yaml (e.g. 2.0.0+4 → 2.0.0)
#   scripts/collect-release.sh --force    overwrite an existing releases/<version>/
#
# Picks up the PRODUCTION build made by `waiter-app/tool/release.sh android production` (and ios-ipa):
#   waiter-app/build/dist/giftcard-waiter-production-<v>.apk / .aab            → android/app-release.apk / .aab
#   waiter-app/build/dist/giftcard-waiter-production-<v>-dart-symbols.zip       → android/dart-symbols-android-<v>.zip
#   waiter-app/build/dist/giftcard-waiter-production-<v>-r8-mapping.txt.gz      → android/r8-mapping-<v>.txt.gz
#   waiter-app/build/ios/ipa/*.ipa (from tool/release.sh ios-ipa production)   → ios/
# Development and staging builds are never filed as releases.
# and always writes source/giftcard-pro-<version>-source.zip, SHA256SUMS and RELEASE.md.
# The release that `latest` pointed to before is moved to releases/previous/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

FULL=$(sed -n 's/^version: *//p' waiter-app/pubspec.yaml)
VERSION=${FULL%%+*}
BUILD=${FULL#*+}
[[ -n "$VERSION" ]] || { echo "No version in waiter-app/pubspec.yaml"; exit 1; }

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

B=waiter-app/build
P="$B/dist/giftcard-waiter-production-$FULL"
[[ -f "$P.apk" && -f "$P.aab" ]] || { echo "No production build of $FULL in $B/dist — run: cd waiter-app && tool/release.sh android production"; exit 1; }

DEST="releases/$VERSION"
if [[ -e "$DEST" && $FORCE -eq 0 ]]; then
  echo "$DEST exists. Use --force to overwrite it."; exit 1
fi

# Move the previous "latest" release (if it is another version) to releases/previous/.
if [[ -L releases/latest ]]; then
  OLD=$(readlink releases/latest)
  if [[ "$OLD" != "$VERSION" && -d "releases/$OLD" ]]; then
    mkdir -p releases/previous
    [[ -e "releases/previous/$OLD" ]] && { echo "releases/previous/$OLD already exists"; exit 1; }
    mv "releases/$OLD" "releases/previous/$OLD"
    echo "Moved $OLD → releases/previous/$OLD"
  fi
fi

mkdir -p "$DEST/android" "$DEST/ios" "$DEST/source"
copied=()
cp "$P.apk" "$DEST/android/app-release.apk"; copied+=(APK)
cp "$P.aab" "$DEST/android/app-release.aab"; copied+=(AAB)
if [[ -f "$P-dart-symbols.zip" ]]; then cp "$P-dart-symbols.zip" "$DEST/android/dart-symbols-android-$FULL.zip"; copied+=(symbols); fi
if [[ -f "$P-r8-mapping.txt.gz" ]]; then cp "$P-r8-mapping.txt.gz" "$DEST/android/r8-mapping-$FULL.txt.gz"; copied+=(mapping); fi
shopt -s nullglob
for ipa in $B/ios/ipa/*.ipa; do cp "$ipa" "$DEST/ios/"; copied+=(IPA); done
shopt -u nullglob

# Source snapshot: everything that belongs in Git, nothing generated, no secrets.
SRC="$ROOT/$DEST/source/giftcard-pro-$VERSION-source.zip"
rm -f "$SRC"
(cd "$ROOT/.." && zip -qr "$SRC" "$(basename "$ROOT")" \
  -x "*/node_modules/*" "*/vendor/*" "*/.next/*" "*/waiter-app/build/*" "*/.dart_tool/*" \
     "*/storage/logs/[!.]*" "*/storage/framework/cache/data/*" \
     "*/storage/framework/sessions/[!.]*" "*/storage/framework/views/[!.]*" "*/storage/framework/testing/[!.]*" "*.sqlite" "*/.phpunit.result.cache" "*.tsbuildinfo" \
     "*/.env" "*/.env.local" "*/.gradle/*" "*/Pods/*" "*/key.properties" "*.jks" "*.keystore" \
     "*/ios/Flutter/Generated.xcconfig" "*/ios/Flutter/Team.xcconfig" "*/ios/Flutter/ephemeral/*" \
     "*/ios/Flutter/flutter_export_environment.sh" "*/android/local.properties" "*/.flutter-plugins-dependencies" \
     "*/.DS_Store" "$(basename "$ROOT")/releases/*" "$(basename "$ROOT")/signing/*")
copied+=(source)

cat > "$DEST/RELEASE.md" <<EOF
# GiftCard Pro $VERSION

- Platform version: $VERSION
- Waiter app: $VERSION (build $BUILD), package / bundle id eu.tapredeem.waiter
- Collected: $(date -u +%Y-%m-%d) by scripts/collect-release.sh
- Contents: ${copied[*]}
- Changes: see CHANGELOG.md, section "$VERSION"
EOF
[[ -z "$(ls -A "$DEST/ios")" ]] && printf '%s\n' "No IPA in this folder: iOS builds are made on a Mac (tool/release.sh ios) and uploaded from Xcode to TestFlight; App Store Connect keeps the build." > "$DEST/ios/README.txt"

(cd "$DEST" && find . -type f ! -name SHA256SUMS | sort | sed 's#^\./##' | while read -r f; do sha256 "$f"; done > SHA256SUMS)
ln -sfn "$VERSION" releases/latest

echo "Release $VERSION collected in $DEST (${copied[*]}); releases/latest → $VERSION"
echo "Now update CURRENT_VERSION.md."
