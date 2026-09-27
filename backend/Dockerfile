# syntax=docker/dockerfile:1.7
# ---------------------------------------------------------------------------
# GiftCard Pro API — production image (PHP 8.4 FPM + nginx-less; served via Caddy php_fastcgi)
# ---------------------------------------------------------------------------
FROM php:8.4-fpm-alpine AS base

RUN apk add --no-cache icu-libs libzip libpng freetype libjpeg-turbo oniguruma tzdata fcgi \
 && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS icu-dev libzip-dev libpng-dev freetype-dev libjpeg-turbo-dev oniguruma-dev linux-headers \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" pdo_mysql intl zip gd bcmath opcache pcntl \
 && pecl install redis \
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
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction --no-progress

# ---------------------------------------------------------------------------
FROM base AS production
ENV APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr

COPY --from=vendor /var/www/html/vendor ./vendor
COPY backend/ ./
RUN rm -f .env database/database.sqlite \
 && composer dump-autoload --optimize --classmap-authoritative --no-dev \
 && php artisan package:discover --ansi \
 && mkdir -p storage/framework/{cache,sessions,views} storage/logs bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R ug+rwX storage bootstrap/cache

COPY infra/docker/php/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

USER www-data
EXPOSE 9000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1
ENTRYPOINT ["entrypoint"]
CMD ["php-fpm"]
