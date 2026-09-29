<?php

declare(strict_types=1);

namespace App\Console\Commands\Crypto;

use App\Crypto\KeyReference;
use App\Crypto\Local\LocalKeystore;
use Illuminate\Console\Command;

final class KeyGenerate extends Command
{
    protected $signature = 'crypto:key:generate {reference : e.g. ks-2026-01/sdm-meta-read}';

    protected $description = 'Generate a random AES-128 key inside the keystore. Only its key check value is shown.';

    public function handle(LocalKeystore $keystore): int
    {
        $reference = new KeyReference((string) $this->argument('reference'));
        $kcv = $keystore->add($reference, random_bytes(16));
        $this->info("{$reference} created, KCV {$kcv}");

        return self::SUCCESS;
    }
}
