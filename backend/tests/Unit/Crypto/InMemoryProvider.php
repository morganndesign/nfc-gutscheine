<?php

declare(strict_types=1);

namespace Tests\Unit\Crypto;

use App\Crypto\KeyReference;
use App\Crypto\Local\LocalCryptoProvider;
use App\Crypto\Local\LocalKeystore;

/** A real LocalCryptoProvider over a temporary keystore, filled with known test keys. */
final class InMemoryProvider
{
    /** @param array<string, string> $keysHex reference => 32 hex */
    public static function with(array $keysHex): LocalCryptoProvider
    {
        $path = sys_get_temp_dir().'/gcp-keystore-'.bin2hex(random_bytes(6)).'.json';
        $keystore = new LocalKeystore($path, random_bytes(32));
        $keystore->create();
        foreach ($keysHex as $reference => $hex) {
            $keystore->add(new KeyReference($reference), (string) hex2bin($hex));
        }
        $provider = new LocalCryptoProvider($keystore);
        $provider->has(new KeyReference('warm/up'));
        unlink($path);

        return $provider;
    }
}
