# ---------------------------------------------------------------------------
# GiftCard Pro API — production image (PHP 8.4 FPM, no web server inside).
# Build context: repository root (needs backend/ and infra/docker/php/).
# One image for three roles (CONTAINER_ROLE): app (php-fpm :9000, reached through
# the gateway via FastCGI), worker, scheduler; each runs pending migrations on start — see infra/docker/php/entrypoint.sh and
# docker-compose.coolify.yml.
#
# Needs no build arguments. Every step that downloads something has a hard time limit
# (`timeout`), so a stalled mirror fails the build with an error instead of blocking it.
# ---------------------------------------------------------------------------
FROM php:8.4-fpm-alpine AS base

# icu-data-full: Alpine's icu-libs ships English locale data only, which printed € 30,00 as "€30.00" in German
# e-mails and voucher PDFs (seen in production 2026-10-04).
RUN apk add --no-cache icu-libs icu-data-full libzip libpng freetype libjpeg-turbo oniguruma tzdata fcgi \
 && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS icu-dev libzip-dev libpng-dev freetype-dev libjpeg-turbo-dev oniguruma-dev linux-headers \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" pdo_mysql intl zip gd bcmath opcache pcntl \
 && yes '' | timeout 600 pecl install redis \
 && docker-php-ext-enable redis \
 && apk del .build-deps \
 && rm -rf /tmp/pear

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY infra/docker/php/php.ini /usr/local/etc/php/conf.d/zz-giftcard.ini
COPY infra/docker/php/www.conf /usr/local/etc/php-fpm.d/zz-www.conf

WORKDIR /var/www/html

# ---------------------------------------------------------------------------
FROM base AS vendor
COPY backend/composer.json backend/composer.lock ./
RUN timeout 900 composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction --no-progress

# ---------------------------------------------------------------------------
FROM base AS production
ENV APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    CONTAINER_ROLE=app

COPY --from=vendor /var/www/html/vendor ./vendor
COPY backend/ ./
# Build-time artisan runs with APP_ENV=build: no database, no public URL yet (the production URL
# check in AppServiceProvider applies only at runtime).
RUN rm -f .env database/database.sqlite \
 && APP_ENV=build composer dump-autoload --optimize --classmap-authoritative --no-dev \
 && APP_ENV=build php artisan package:discover --ansi \
 && mkdir -p storage/app/private storage/app/public storage/framework/cache storage/framework/sessions storage/framework/views storage/framework/testing storage/logs bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R ug+rwX storage bootstrap/cache

COPY infra/docker/php/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

USER www-data
EXPOSE 9000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1
ENTRYPOINT ["entrypoint"]
CMD ["php-fpm"]
