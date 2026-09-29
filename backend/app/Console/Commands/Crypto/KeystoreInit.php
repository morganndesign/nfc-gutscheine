<?php

declare(strict_types=1);

namespace App\Console\Commands\Crypto;

use App\Crypto\Local\LocalKeystore;
use Illuminate\Console\Command;

final class KeystoreInit extends Command
{
    protected $signature = 'crypto:keystore:init';

    protected $description = 'Create the empty encrypted keystore of the local crypto provider (CRYPTO_KEYSTORE_KEY must be set).';

    public function handle(LocalKeystore $keystore): int
    {
        $keystore->create();
        $this->info("Keystore created: {$keystore->path()}");
        $this->line('Back it up together with CRYPTO_KEYSTORE_KEY, stored separately; one without the other is useless.');

        return self::SUCCESS;
    }
}
