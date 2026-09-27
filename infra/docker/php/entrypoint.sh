#!/bin/sh
# Container entrypoint: warms Laravel caches and (for the "app" role only) runs migrations.
set -e

if [ "${CONTAINER_ROLE:-app}" = "app" ]; then
  if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
    # --isolated takes a cache lock so two app containers never migrate at the same time.
    php artisan migrate --force --isolated --no-interaction
    php artisan db:seed --class='Database\Seeders\RolesAndPermissionsSeeder' --force --no-interaction
    php artisan db:seed --class='Database\Seeders\NotificationTemplateSeeder' --force --no-interaction
    php artisan db:seed --class='Database\Seeders\SystemSettingsSeeder' --force --no-interaction
  fi
fi

php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

exec "$@"
