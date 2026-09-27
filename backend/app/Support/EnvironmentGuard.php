<?php

declare(strict_types=1);

namespace App\Support;

use RuntimeException;

/**
 * Refuses to boot a staging or production API whose public URLs are missing or point at a
 * development machine (the config files fall back to http://localhost when a variable is unset).
 * Without this, a forgotten FRONTEND_URL / CARD_BASE_URL would silently print localhost links on
 * gift cards and in e-mails. The container then fails its start and the deploy stops.
 */
final class EnvironmentGuard
{
    private const LOCAL_HOSTS = ['localhost', '127.0.0.1', '::1', '[::1]', '0.0.0.0', '10.0.2.2'];

    /**
     * @param  array<string, mixed>  $urls  config key => configured URL
     */
    public static function assertPublicUrls(string $environment, array $urls): void
    {
        if (! in_array($environment, ['production', 'staging'], true)) {
            return;
        }

        foreach ($urls as $key => $url) {
            $value = is_string($url) ? $url : '';
            $host = strtolower((string) parse_url($value, PHP_URL_HOST));
            if (! str_starts_with($value, 'https://') || preg_match('/^[a-z0-9.-]+$/', $host) !== 1 || in_array($host, self::LOCAL_HOSTS, true)
                || str_ends_with($host, '.test') || str_ends_with($host, '.local')) {
                throw new RuntimeException(sprintf(
                    '%s must be the https URL of this %s server, got "%s". Set APP_URL, FRONTEND_URL and CARD_BASE_URL in backend/.env.%s.',
                    $key,
                    $environment,
                    $value,
                    $environment,
                ));
            }
        }
    }
}
