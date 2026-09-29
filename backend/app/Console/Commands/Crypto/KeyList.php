<?php

declare(strict_types=1);

namespace App\Console\Commands\Crypto;

use App\Crypto\Local\LocalKeystore;
use Illuminate\Console\Command;

final class KeyList extends Command
{
    protected $signature = 'crypto:key:list';

    protected $description = 'List the keys of the keystore: reference, key check value, creation time. Never the material.';

    public function handle(LocalKeystore $keystore): int
    {
        $rows = [];
        foreach ($keystore->read() as $reference => $entry) {
            $rows[] = [$reference, $entry['algorithm'], $entry['kcv'], $entry['created_at']];
        }
        $this->table(['Reference', 'Algorithm', 'KCV', 'Created'], $rows);

        return self::SUCCESS;
    }
}
