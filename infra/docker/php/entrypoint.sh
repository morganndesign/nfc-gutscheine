#!/bin/sh
# ---------------------------------------------------------------------------
# GiftCard Pro Laravel container entrypoint. One image, three roles (CONTAINER_ROLE):
#
#   app        php-fpm on :9000 (behind the gateway)
#   worker     queue worker
#   scheduler  cron replacement (schedule:work)
#
# docker-compose.coolify.yml has no depends_on: Coolify starts all containers at once.
# The order is enforced here instead:
#   1. APP_KEY (generated once into the storage volume unless set in Coolify)
#   2. wait until MySQL and Redis accept connections (fresh volumes can take minutes)
#   3. run the migrations; --isolated (Redis lock) lets exactly one container migrate,
#      the others wait until no migration is pending
#   4. app only: reference data seeders (idempotent)
#   5. cache config/routes/views/events, then start the process
# ---------------------------------------------------------------------------
set -eu
cd /var/www/html
ROLE="${CONTAINER_ROLE:-app}"

fail() { echo "[entrypoint:$ROLE] ERROR: $*" >&2; exit 1; }
log() { echo "[entrypoint:$ROLE] $*"; }

case "$ROLE" in
  app|worker|scheduler) ;;
  *) fail "Unknown CONTAINER_ROLE '$ROLE' (app, worker, scheduler)." ;;
esac

# --- 1. Public URL ---------------------------------------------------------------
# Coolify sets SERVICE_URL_GATEWAY (with scheme) / SERVICE_FQDN_GATEWAY (without) from the
# domain configured for the gateway service. An explicit APP_URL wins.
url="${APP_URL:-}"
[ -n "$url" ] || url="${SERVICE_URL_GATEWAY:-}"
if [ -z "$url" ] && [ -n "${SERVICE_FQDN_GATEWAY:-}" ]; then url="https://${SERVICE_FQDN_GATEWAY}"; fi
url="${url%%,*}"      # several domains: the first one is canonical
url="${url%/}"
[ -n "$url" ] || fail "No public URL. Assign a domain to the 'gateway' service in Coolify (e.g. https://app.giftcardpro.at) or set APP_URL."
case "$url" in http://*|https://*) ;; *) url="https://$url" ;; esac
host="${url#*://}"; host="${host%%/*}"; hostname="${host%%:*}"
export APP_URL="$url"
export FRONTEND_URL="${FRONTEND_URL:-$url}"
export SESSION_DOMAIN="${SESSION_DOMAIN:-$hostname}"
export SANCTUM_STATEFUL_DOMAINS="${SANCTUM_STATEFUL_DOMAINS:-$host}"
export MAIL_FROM_ADDRESS="${MAIL_FROM_ADDRESS:-no-reply@$hostname}"

[ -n "${DB_PASSWORD:-}" ] || fail "DB_PASSWORD is empty — Coolify should generate SERVICE_PASSWORD_MYSQL. Check the Environment Variables of this resource."
[ -n "${REDIS_PASSWORD:-}" ] || fail "REDIS_PASSWORD is empty — Coolify should generate SERVICE_PASSWORD_REDIS. Check the Environment Variables of this resource."

# --- 2. APP_KEY ----------------------------------------------------------------
# Set APP_KEY in Coolify to manage it yourself. Otherwise the first container to start
# generates one into the shared storage volume; `ln` is atomic, so when several containers
# start at the same time exactly one key wins and all of them use it.
KEY_FILE=storage/app/.app-key
if [ -z "${APP_KEY:-}" ]; then
  if [ ! -s "$KEY_FILE" ]; then
    tmp="$KEY_FILE.$$"
    (umask 077; php -r 'echo "base64:".base64_encode(random_bytes(32));' > "$tmp")
    if ln "$tmp" "$KEY_FILE" 2>/dev/null; then
      log "Generated APP_KEY and stored it in the storage volume ($KEY_FILE). Back it up (see docs/DEPLOYMENT.md)."
    fi
    rm -f "$tmp"
  fi
  [ -s "$KEY_FILE" ] || fail "Could not create $KEY_FILE (is the laravel-storage volume writable?)"
  APP_KEY="$(cat "$KEY_FILE")"
  export APP_KEY
fi

# --- 3. Wait for MySQL and Redis -----------------------------------------------
WAIT_SECONDS="${STARTUP_WAIT_SECONDS:-900}"
waited=0
until php -r '
  try {
    new PDO(sprintf("mysql:host=%s;port=%s;dbname=%s", getenv("DB_HOST"), getenv("DB_PORT") ?: "3306", getenv("DB_DATABASE")),
      getenv("DB_USERNAME"), getenv("DB_PASSWORD"), [PDO::ATTR_TIMEOUT => 3]);
  } catch (Throwable $e) { fwrite(STDERR, "MySQL not ready: ".$e->getMessage()."\n"); exit(1); }
  try {
    $r = new Redis();
    $r->connect(getenv("REDIS_HOST"), (int) (getenv("REDIS_PORT") ?: 6379), 3);
    if ((string) getenv("REDIS_PASSWORD") !== "") { $r->auth(getenv("REDIS_PASSWORD")); }
    $r->ping();
  } catch (Throwable $e) { fwrite(STDERR, "Redis not ready: ".$e->getMessage()."\n"); exit(1); }
'; do
  waited=$((waited + 5))
  [ "$waited" -lt "$WAIT_SECONDS" ] || fail "MySQL/Redis not reachable after ${WAIT_SECONDS}s (see the message above)."
  sleep 5
done
log "MySQL and Redis are reachable."

# --- 4. Migrations -------------------------------------------------------------
# Every container tries; the Redis lock (--isolated) lets only one run at a time, the
# others skip and then wait until nothing is pending. A failing migration stops this
# container with the error in its log; Coolify restarts it (restart: unless-stopped).
waited=0
while :; do
  php artisan migrate --force --isolated --no-interaction
  if status="$(php artisan migrate:status --no-interaction 2>&1)" && ! printf '%s\n' "$status" | grep -q 'Pending'; then
    break
  fi
  waited=$((waited + 3))
  [ "$waited" -lt "$WAIT_SECONDS" ] || fail "Migrations still pending after ${WAIT_SECONDS}s: $status"
  sleep 3
done
log "Database schema is up to date."

if [ "$ROLE" = "app" ]; then
  php artisan db:seed --class='Database\Seeders\RolesAndPermissionsSeeder' --force --no-interaction
  php artisan db:seed --class='Database\Seeders\NotificationTemplateSeeder' --force --no-interaction
  php artisan db:seed --class='Database\Seeders\SystemSettingsSeeder' --force --no-interaction
fi

# --- 5. Start --------------------------------------------------------------------
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
log "Starting: $*"
exec "$@"
