<?php

declare(strict_types=1);

return [
    /*
    | Where secret keys live (App\Crypto\CryptoProvider). Business logic never knows which provider runs.
    | "local": one AES-256-GCM encrypted keystore file, opened with CRYPTO_KEYSTORE_KEY at boot.
    */
    'provider' => env('CRYPTO_PROVIDER', 'local'),

    'local' => [
        // Outside the repository and outside the web root; mounted as a volume in containers.
        'keystore_path' => env('CRYPTO_KEYSTORE_PATH', storage_path('app/private/crypto/keystore.json')),
        // base64 of 32 random bytes; the only secret in the environment (the keys themselves are in the keystore).
        'master_key' => env('CRYPTO_KEYSTORE_KEY'),
    ],
];
