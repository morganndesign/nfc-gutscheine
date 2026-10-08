#!/usr/bin/env bash
# GiftCard Pro security checks in one command (security/README.md).
#
#   security/run.sh              # everything that is available
#   security/run.sh tests deps   # only some: tests secrets deps code deployment zap
#
# Environment:
#   DEPLOY_URL  deployment checked read-only        (default https://app.giftcardpro.at)
#   LOCAL_URL   local stack for the ZAP scans        (default http://127.0.0.1:3000; never a public host)
#
# Tools are used when installed, otherwise through Docker: gitleaks, osv-scanner, semgrep, ZAP.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_URL="${DEPLOY_URL:-https://app.giftcardpro.at}"
LOCAL_URL="${LOCAL_URL:-http://127.0.0.1:3000}"
STEPS=("$@")
[ ${#STEPS[@]} -eq 0 ] && STEPS=(tests secrets deps code deployment zap)
REPORTS="$ROOT/security/reports"
mkdir -p "$REPORTS"
FAILED=()

want() { [[ " ${STEPS[*]} " == *" $1 "* ]]; }
have() { command -v "$1" >/dev/null 2>&1; }
step() { echo; echo "━━ $1"; }
result() { if [ "$1" -eq 0 ]; then echo "✓ $2"; else echo "✗ $2"; FAILED+=("$2"); fi; }

if want tests; then
  step "Security tests (backend: tenant isolation, roles, attacks, sweep over every route)"
  (cd "$ROOT/backend" && vendor/bin/phpunit --no-progress \
    --filter 'Security|Abuse|PermissionMatrix|Permissions|TenantIsolation|Hardening|PlatformAdminAuthorization|AccountEmailInjection|Partner' )
  result $? "security tests"
  (cd "$ROOT/dashboard" && node --test --experimental-strip-types src/lib/forms.test.ts >/dev/null)
  result $? "dashboard forms never put typed values in the URL"
fi

if want secrets; then
  step "Secrets in the code and the whole git history (gitleaks)"
  if have gitleaks; then
    gitleaks git --no-banner --redact --config "$ROOT/.gitleaks.toml" "$ROOT"
  else
    docker run --rm -v "$ROOT:/repo" zricethezav/gitleaks:latest git --no-banner --redact --config /repo/.gitleaks.toml /repo
  fi
  result $? "no secrets in git"
fi

if want deps; then
  step "Libraries with known vulnerabilities (osv-scanner: composer, npm, Flutter)"
  if have osv-scanner; then
    osv-scanner scan source -r --config "$ROOT/osv-scanner.toml" "$ROOT"
  else
    docker run --rm -v "$ROOT:/src" ghcr.io/google/osv-scanner:latest scan source -r --config /src/osv-scanner.toml /src
  fi
  result $? "no vulnerable libraries"
  (cd "$ROOT/backend" && composer audit --no-interaction)
  result $? "composer audit"
  (cd "$ROOT/dashboard" && npm audit --omit=dev --audit-level=moderate)
  result $? "npm audit (shipped packages)"
fi

if want code; then
  step "Static analysis for dangerous code patterns (semgrep)"
  PACKS=(--config p/php --config p/typescript --config p/react --config p/nextjs --config p/secrets --config p/owasp-top-ten --config p/jwt)
  TARGETS=(backend/app backend/routes backend/config backend/resources dashboard/src waiter-app/lib integrations)
  if have semgrep; then
    (cd "$ROOT" && semgrep scan "${PACKS[@]}" --metrics=off --error --quiet "${TARGETS[@]}")
  else
    docker run --rm -v "$ROOT:/src" -w /src semgrep/semgrep semgrep scan "${PACKS[@]}" --metrics=off --error --quiet "${TARGETS[@]}"
  fi
  result $? "no dangerous patterns"
fi

if want deployment; then
  step "Deployment, read-only: HTTPS, headers, cookies, CORS, debug, internal files ($DEPLOY_URL)"
  BASE_URL="$DEPLOY_URL" node "$ROOT/security/check-deployment.mjs"
  result $? "deployment $DEPLOY_URL"
fi

if want zap; then
  step "OWASP ZAP against the local stack ($LOCAL_URL)"
  if [[ ! "$LOCAL_URL" =~ ^https?://(127\.0\.0\.1|localhost)(:[0-9]+)?$ ]]; then
    echo "✗ ZAP only scans a local stack (LOCAL_URL=$LOCAL_URL)"; FAILED+=("zap")
  elif ! curl -fsS -o /dev/null "$LOCAL_URL/login"; then
    echo "– skipped: no local stack at $LOCAL_URL (backend: php artisan serve; dashboard: npm run build && npx next start)"
  else
    WORK="$(mktemp -d)"; chmod 777 "$WORK"
    cp "$ROOT/security/zap-rules.tsv" "$ROOT/security/zap-api-rules.tsv" "$ROOT/docs/partner/openapi.yaml" "$WORK/"
    docker run --rm --network host -v "$WORK:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
      zap-baseline.py -t "$LOCAL_URL/login" -m 2 -c zap-rules.tsv -r zap-baseline.html
    result $? "ZAP baseline (dashboard)"
    docker run --rm --network host -v "$WORK:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
      zap-api-scan.py -t openapi.yaml -f openapi -O "$LOCAL_URL" -c zap-api-rules.tsv -r zap-partner-api.html
    result $? "ZAP API scan (POS partner API)"
    cp "$WORK"/*.html "$REPORTS/" 2>/dev/null
    echo "Reports: security/reports/"
  fi
fi

echo
if [ ${#FAILED[@]} -eq 0 ]; then echo "All security checks passed."; exit 0; fi
echo "Failed: ${FAILED[*]}"; exit 1
