#!/usr/bin/env bash
# Checks that the project folder matches PROJECT_STRUCTURE.md. Read-only; prints OK / FAIL per check.
#   scripts/verify-structure.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
ok()  { printf '  OK    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

echo "Folders"
for d in backend dashboard waiter-app nfc docs e2e infra releases releases/previous signing assets scripts; do
  [[ -d $d ]] && ok "$d/" || bad "$d/ missing"
done
for f in README.md PROJECT_STRUCTURE.md CURRENT_VERSION.md RUNNING_THE_PROJECT.md QUICK_COMMANDS.md CHANGELOG.md \
         docker-compose.yml docker-compose.dev.yml backend/artisan dashboard/package.json waiter-app/pubspec.yaml \
         waiter-app/tool/release.sh waiter-app/config/development.json waiter-app/config/staging.json \
         waiter-app/config/production.json scripts/collect-release.sh; do
  [[ -f $f ]] && ok "$f" || bad "$f missing"
done
[[ -e frontend ]] && bad "old folder frontend/ still exists (renamed to dashboard/)"

echo "Versions"
APP=$(sed -n 's/^version: *//p' waiter-app/pubspec.yaml); APPV=${APP%%+*}
LATEST=$(readlink releases/latest 2>/dev/null || true)
[[ -n "$LATEST" && -d "releases/$LATEST" ]] && ok "releases/latest → $LATEST" || bad "releases/latest is not a link to a release folder"
if [[ "$LATEST" == "$APPV" ]]; then
  ok "waiter-app/pubspec.yaml $APP matches latest"
elif [[ "$(printf '%s\n%s\n' "$LATEST" "$APPV" | sort -V | tail -1)" == "$APPV" ]] && grep -q "^## $APPV" CHANGELOG.md \
     && grep -Eq "Current development release(\*\*)? \| \*\*$APPV" CURRENT_VERSION.md; then
  ok "waiter-app/pubspec.yaml $APP is the development version after release $LATEST (CHANGELOG + CURRENT_VERSION agree)"
else
  bad "pubspec $APP ≠ releases/latest $LATEST (and not a documented development version)"
fi
grep -q "Current platform version | \*\*$LATEST\*\*" CURRENT_VERSION.md && ok "CURRENT_VERSION.md names $LATEST" || bad "CURRENT_VERSION.md does not name $LATEST as current platform version"
grep -q "^## $LATEST" CHANGELOG.md && ok "CHANGELOG.md has a $LATEST section" || bad "CHANGELOG.md has no $LATEST section"

echo "Releases"
for r in releases/[0-9]* releases/previous/*; do
  [[ -d $r ]] || continue
  if [[ -f $r/SHA256SUMS ]]; then
    if (cd "$r" && while read -r h f; do [[ "$(sha256 "$f" | cut -d' ' -f1)" == "$h" ]] || exit 1; done < SHA256SUMS); then ok "$r checksums"; else bad "$r checksum mismatch"; fi
  else bad "$r has no SHA256SUMS"; fi
  [[ -f $r/RELEASE.md ]] || bad "$r has no RELEASE.md"
done
n=$(ls -d releases/[0-9]* 2>/dev/null | wc -l | tr -d ' ')
[[ "$n" == 1 ]] && ok "exactly one current release folder" || bad "$n release folders at releases/ top level (older ones belong in previous/)"

echo "Duplicates"
dups=$(find releases assets docs -type f ! -name SHA256SUMS ! -name RELEASE.md ! -name README.txt ! -name .DS_Store -size +0 -print0 \
  | xargs -0 -I{} sh -c 'if command -v sha256sum >/dev/null; then sha256sum "{}"; else shasum -a 256 "{}"; fi' \
  | sort | awk '{c[$1]++; f[$1]=f[$1]" "$2} END{for(h in c) if(c[h]>1) print f[h]}')
[[ -z "$dups" ]] && ok "no identical files in releases/, assets/, docs/" || { bad "identical files:"; echo "$dups"; }
stray=$(find . -maxdepth 1 -type f \( -name '*.zip' -o -name '*.apk' -o -name '*.aab' -o -name '*.ipa' \))
[[ -z "$stray" ]] && ok "no loose archives or builds at the top level" || bad "loose files: $stray"

echo "Secrets"
grep -qx '/signing/' .gitignore && grep -qx '/releases/' .gitignore && ok ".gitignore excludes signing/ and releases/" || bad ".gitignore must list /signing/ and /releases/"
grep -qx 'signing' .dockerignore && ok ".dockerignore excludes signing" || bad ".dockerignore must list signing"
k=$(find . -path ./signing -prune -o \( -name '*.jks' -o -name '*.keystore' \) -print | grep -v node_modules)
[[ -z "$k" ]] && ok "keystores only in signing/" || bad "keystore outside signing/: $k"
for z in $(find releases -name '*-source.zip'); do
  if unzip -Z1 "$z" | grep -Eq '(^|/)(key\.properties|\.env)$|\.jks$'; then bad "$z contains secrets"; else ok "$z has no secrets"; fi
done

echo "Scripts"
for s in scripts/*.sh waiter-app/tool/release.sh infra/scripts/*.sh; do bash -n "$s" && ok "syntax $s" || bad "syntax $s"; done

echo "Configuration"
legacy=0
for f in waiter-app/tool/release.env backend/.env.staging waiter-app/config/.env; do
  if [[ -e $f ]]; then bad "legacy / stray configuration file: $f"; legacy=1; fi
done
[[ $legacy == 0 ]] && ok "no legacy configuration files (waiter-app/tool/release.env removed)"
grep -q "CARD_DOMAIN =" waiter-app/ios/Runner.xcodeproj/project.pbxproj \
  && bad "CARD_DOMAIN is set in the Xcode project (must come from Environment.xcconfig)" \
  || ok "iOS app-link host comes from the environment, not the Xcode project"
grep -Eq 'BACKEND_INTERNAL_URL *\?\?' dashboard/next.config.ts \
  && bad "dashboard/next.config.ts has a default backend URL" || ok "dashboard has no default backend URL"
cfgbad=0
for env in development staging production; do
  f=waiter-app/config/$env.json
  a=$(sed -n 's/.*"APP_ENV"[^"]*"\([^"]*\)".*/\1/p' "$f"); u=$(sed -n 's/.*"API_BASE_URL"[^"]*"\([^"]*\)".*/\1/p' "$f")
  [[ "$a" == "$env" ]] || { bad "$f: APP_ENV is '$a'"; cfgbad=1; }
  if [[ $env != development && -n "$u" && "$u" != https://* ]]; then bad "$f: API_BASE_URL must be https"; cfgbad=1; fi
  if [[ $env != development ]] && grep -Eq 'localhost|127\.0\.0\.1|10\.0\.2\.2|192\.168\.' "$f"; then bad "$f points at a development address"; cfgbad=1; fi
done
[[ $cfgbad == 0 ]] && ok "waiter-app/config: APP_ENV matches each file, staging/production https and no development addresses"
lit=$(grep -rn "://" waiter-app/lib --include=*.dart | grep -v "^waiter-app/lib/l10n/\|pseudo_app_localizations" | grep -vE ":[0-9]+:\s*//" || true)
[[ -z "$lit" ]] && ok "no URL literals in waiter-app/lib" || { bad "URL literals in waiter-app/lib:"; echo "$lit"; }
for f in backend/.env.production.example backend/.env.staging.example .env.production.example .env.staging.example; do
  [[ -f $f ]] || bad "$f missing"
done

echo "Links in documentation"
python3 - <<'EOF' || fail=1
import os, re, sys
bad = 0
files = [f for f in os.listdir('.') if f.endswith('.md')]
for d in ['docs', 'nfc', 'assets', 'e2e', 'waiter-app', 'signing']:
    for r, _, fs in os.walk(d):
        if 'node_modules' in r or '/build' in r: continue
        files += [os.path.join(r, f) for f in fs if f.endswith('.md')]
for f in files:
    text = re.sub(r'```.*?```', '', open(f, encoding='utf-8').read(), flags=re.S)   # code blocks
    text = re.sub(r'`[^`\n]*`', '', text)                                          # inline code
    for m in re.finditer(r'\]\(([^)#\s]+)(#[^)]*)?\)', text):
        t = m.group(1)
        if re.match(r'[a-z]+:', t) or t.startswith('/'): continue   # web URLs, site paths
        p = os.path.normpath(os.path.join(os.path.dirname(f), t))
        if not os.path.exists(p):
            print(f'  FAIL  {f}: link to {t}'); bad += 1
print(f'  {"OK   " if not bad else "FAIL "} {len(files)} Markdown files, {bad} broken links')
sys.exit(1 if bad else 0)
EOF

echo
[[ $fail == 0 ]] && echo "Structure OK" || { echo "Structure has problems (see FAIL lines)"; exit 1; }
