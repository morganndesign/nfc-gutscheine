<?php

declare(strict_types=1);

namespace App\Console\Commands\Crypto;

use App\Crypto\Local\LocalKeystore;
use Illuminate\Console\Command;

/**
 * Rotates the master key: re-encrypts the keystore under CRYPTO_KEYSTORE_NEW_KEY. Afterwards set
 * CRYPTO_KEYSTORE_KEY to the new value and remove CRYPTO_KEYSTORE_NEW_KEY.
 */
final class KeystoreRekey extends Command
{
    protected $signature = 'crypto:keystore:rekey';

    protected $description = 'Re-encrypt the keystore under a new master key (CRYPTO_KEYSTORE_NEW_KEY).';

    public function handle(LocalKeystore $keystore): int
    {
        $new = LocalKeystore::decodeMasterKey((string) getenv('CRYPTO_KEYSTORE_NEW_KEY'));
        $count = count($keystore->rekey($new)->read());
        $this->info("Keystore re-encrypted ({$count} keys). Now set CRYPTO_KEYSTORE_KEY to the new key and remove CRYPTO_KEYSTORE_NEW_KEY.");

        return self::SUCCESS;
    }
}
