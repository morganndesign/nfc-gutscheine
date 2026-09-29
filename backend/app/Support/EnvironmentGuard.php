<?php

declare(strict_types=1);

namespace App\Support;

use App\Crypto\Exceptions\KeystoreException;
use App\Crypto\Local\LocalKeystore;
use RuntimeException;

/**
 * Refuses to boot a staging or production API whose public URLs are missing or point at a
 * development machine (the config files fall back to http://localhost when a variable is unset).
 * Without this, a forgotten FRONTEND_URL would silently print localhost links on
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
                    '%s must be the https URL of this %s server, got "%s". In Coolify: give the gateway service an https domain (or set APP_URL and FRONTEND_URL).',
                    $key,
                    $environment,
                    $value,
                ));
            }
        }
    }

    /**
     * A staging or production server keeps card keys in the local keystore, opened with CRYPTO_KEYSTORE_KEY. Without
     * it no card can be personalised, tapped or paid with; the container refuses to start instead of failing at the
     * first tap. The key is never generated here: it must not live next to the keystore it protects.
     */
    public static function assertCryptoKeystore(string $environment, string $provider, mixed $masterKey): void
    {
        if (! in_array($environment, ['production', 'staging'], true) || $provider !== 'local') {
            return;
        }
        try {
            LocalKeystore::decodeMasterKey(is_string($masterKey) ? $masterKey : null);
        } catch (KeystoreException) {
            throw new RuntimeException(
                'CRYPTO_KEYSTORE_KEY must be "base64:" + 32 random bytes (openssl rand -base64 32, prefixed with base64:). '
                .'Set it in Coolify and keep a copy offline: it opens the card keystore; without it no card works.'
            );
        }
    }
}
