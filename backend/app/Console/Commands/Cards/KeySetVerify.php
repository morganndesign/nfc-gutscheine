<?php

declare(strict_types=1);

namespace App\Console\Commands\Cards;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;
use App\Enums\KeySetStatus;
use App\Models\KeySet;
use Illuminate\Console\Command;
use Throwable;

/**
 * Tamper check of the card keys: every root key of every usable key set must be in the provider with the key
 * check value recorded at its ceremony. A swapped keystore or a changed key fails here before any card does.
 */
final class KeySetVerify extends Command
{
    protected $signature = 'cards:key-set:verify';

    protected $description = 'Compare the key check values of every usable key set with the key provider.';

    public function handle(CryptoProvider $provider): int
    {
        $problems = [];
        /** @var iterable<KeySet> $sets */
        $sets = KeySet::query()->where('status', '!=', KeySetStatus::Retired->value)->get();
        foreach ($sets as $set) {
            foreach (KeySetCreate::ROLES as $role) {
                $recorded = $set->key_check_values[$role] ?? null;
                try {
                    $actual = $provider->keyCheckValue(KeyReference::of($set->version, $role));
                } catch (Throwable) {
                    $actual = null;
                }
                if ($recorded === null || $actual === null || ! hash_equals(strtoupper($recorded), strtoupper($actual))) {
                    $problems[] = "{$set->version}/{$role}: ".($actual === null ? 'missing in the provider' : 'key check value differs');
                }
            }
        }
        if ($problems !== []) {
            foreach ($problems as $problem) {
                $this->error($problem);
            }
            report(new \RuntimeException('Card key check failed: '.implode('; ', $problems)));

            return self::FAILURE;
        }
        $this->info('All card keys match their key check values.');

        return self::SUCCESS;
    }
}
