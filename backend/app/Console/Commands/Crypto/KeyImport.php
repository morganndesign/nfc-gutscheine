<?php

declare(strict_types=1);

namespace App\Console\Commands\Crypto;

use App\Crypto\KeyReference;
use App\Crypto\Local\LocalKeystore;
use Illuminate\Console\Command;

/** For keys that exist outside (a key ceremony, lab cards with known keys). The key is typed, never an argument. */
final class KeyImport extends Command
{
    protected $signature = 'crypto:key:import {reference : e.g. ks-2026-01/sdm-meta-read} {--kcv= : Expected key check value (6 hex)}';

    protected $description = 'Import an AES-128 key (32 hex characters, typed hidden) into the keystore.';

    public function handle(LocalKeystore $keystore): int
    {
        $reference = new KeyReference((string) $this->argument('reference'));
        $hex = trim((string) $this->secret('Key (32 hex characters)'));
        if (preg_match('/^[0-9A-Fa-f]{32}$/', $hex) !== 1) {
            $this->error('The key must be 32 hex characters.');

            return self::FAILURE;
        }
        $material = (string) hex2bin($hex);

        $expected = $this->option('kcv');
        if (is_string($expected) && strtoupper($expected) !== LocalKeystore::kcv($material)) {
            $this->error('The key does not match the expected key check value; nothing was imported.');

            return self::FAILURE;
        }

        $kcv = $keystore->add($reference, $material);
        $this->info("{$reference} imported, KCV {$kcv}");

        return self::SUCCESS;
    }
}
