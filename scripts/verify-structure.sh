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
         docker-compose.coolify.yml docker-compose.dev.yml .env.production.example \
         infra/docker/gateway/Caddyfile infra/docker/gateway/Dockerfile infra/docker/php/entrypoint.sh backend/artisan dashboard/package.json waiter-app/pubspec.yaml \
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
for s in scripts/*.sh waiter-app/tool/release.sh; do bash -n "$s" && ok "syntax $s" || bad "syntax $s"; done
sh -n infra/docker/php/entrypoint.sh && ok "syntax infra/docker/php/entrypoint.sh (POSIX sh)" || bad "syntax infra/docker/php/entrypoint.sh"

echo "Configuration"
legacy=0
for f in waiter-app/tool/release.env backend/.env.staging backend/.env.production .env.production waiter-app/config/.env; do
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

echo "Deployment (Coolify)"
dep=0
for f in docker-compose.yml .env.staging.example backend/.env.production.example backend/.env.staging.example \
         .github/workflows/deploy.yml infra/caddy infra/scripts; do
  if [[ -e $f ]]; then bad "old GHCR deployment file still exists: $f"; dep=1; fi
done
[[ $dep == 0 ]] && ok "no files of the old GHCR deployment"
if grep -rqsE 'ghcr\.io|image: *\$\{' docker-compose.coolify.yml .github/workflows; then bad "registry images referenced (everything must build from source)"
else ok "docker-compose.coolify.yml builds from source, no registry"; fi
grep -Eq '^\s+ports:' docker-compose.coolify.yml && bad "docker-compose.coolify.yml publishes host ports (Coolify's proxy routes the domain)" \
  || ok "no published host ports"
for svc in gateway api worker scheduler web mysql redis backup; do
  grep -Eq "^  $svc:" docker-compose.coolify.yml || { bad "service $svc missing in docker-compose.coolify.yml"; dep=1; }
done
[[ $dep == 0 ]] && ok "all eight services defined"
grep -q 'SERVICE_URL_GATEWAY_80' docker-compose.coolify.yml && ok "gateway gets its domain from Coolify (SERVICE_URL_GATEWAY_80)" || bad "gateway domain variable missing"
if grep -nE '^\s*env_file:|--env-file' docker-compose.coolify.yml backend/Dockerfile dashboard/Dockerfile infra/docker/gateway/Dockerfile >/dev/null; then
  bad "env_file / --env-file in the Coolify deployment (configuration must come from environment: only)"
else ok "no env_file: the Coolify stack reads configuration from environment: only"; fi
grep -Eq 'exclude_from_hc' docker-compose.coolify.yml && bad "exclude_from_hc makes plain docker compose reject the file" || ok "docker-compose.coolify.yml uses only standard Compose keys"
if grep -nE '^\s*(depends_on|profiles):|restart: *"?no"?|service_(healthy|completed_successfully)|^x-|<<:' docker-compose.coolify.yml >/dev/null; then
  bad "docker-compose.coolify.yml uses depends_on / profiles / restart:no / anchors (Coolify must start every service at once)"
else ok "no depends_on, profiles, one-shot services or anchors: Coolify starts every service in one step"; fi
n_build=$(grep -cE '^\s+build:' docker-compose.coolify.yml); n_var=$(grep -cE '^\s+dockerfile: \$\{[A-Z_]+:-[^}]+\}' docker-compose.coolify.yml)
[[ "$n_build" == "$n_var" ]] && ok "every build uses a \${VAR:-default} Dockerfile path (Coolify injects no ARGs, no secrets in image history)" \
  || bad "$((n_build - n_var)) build(s) without a \${VAR:-default} dockerfile path: Coolify would inject an ARG for every variable"
grep -qE '^\s*ARG ' backend/Dockerfile dashboard/Dockerfile infra/docker/gateway/Dockerfile && bad "Dockerfiles declare ARGs (must need no build arguments)" || ok "Dockerfiles need no build arguments"
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
  # Run from an empty directory so that no .env file can be picked up.
  empty="$(mktemp -d)"
  (cd "$empty" && docker compose -f "$ROOT/docker-compose.coolify.yml" --project-directory "$ROOT" config --quiet 2>/dev/null) \
    && ok "docker compose config passes without any .env file" || bad "docker compose config fails for docker-compose.coolify.yml"
  rmdir "$empty"
fi

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
