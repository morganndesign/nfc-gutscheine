<?php

declare(strict_types=1);

namespace App\Console\Commands\Cards;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;
use App\Crypto\Local\LocalKeystore;
use App\Enums\KeySetStatus;
use App\Models\KeySet;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Key ceremony for a new card key set (architecture §9.2): generates the four root keys inside the keystore,
 * records their key check values, and makes the new set the active one. Every earlier active set becomes
 * `verify_only`: its cards keep working, new batches use the new keys (rotation).
 */
final class KeySetCreate extends Command
{
    public const ROLES = ['root-k0', 'root-k1', 'root-k2', 'root-k3'];

    protected $signature = 'cards:key-set:create {version : e.g. ks-2026-01} {--manufacturer=in-house : who prints the cards}';

    protected $description = 'Generate the root keys of a new card key set and make it the active one (rotation).';

    public function handle(LocalKeystore $keystore, CryptoProvider $provider): int
    {
        $version = (string) $this->argument('version');
        if (preg_match('/^[a-z0-9][a-z0-9._-]{0,31}$/', $version) !== 1) {
            $this->error('The version is 1–32 characters of a–z, 0–9, dot, dash, underscore.');

            return self::FAILURE;
        }
        if (KeySet::query()->where('version', $version)->exists()) {
            $this->error("Key set {$version} already exists.");

            return self::FAILURE;
        }
        foreach (self::ROLES as $role) {
            if ($provider->has(KeyReference::of($version, $role))) {
                $this->error("{$version}/{$role} is already in the keystore; refusing to overwrite a key.");

                return self::FAILURE;
            }
        }

        $kcv = [];
        foreach (self::ROLES as $role) {
            $kcv[$role] = $keystore->add(KeyReference::of($version, $role), random_bytes(16));
        }

        DB::transaction(function () use ($version, $kcv): void {
            KeySet::query()->where('status', KeySetStatus::Active->value)->update(['status' => KeySetStatus::VerifyOnly->value]);
            KeySet::query()->create([
                'version' => $version,
                'manufacturer' => (string) $this->option('manufacturer'),
                'status' => KeySetStatus::Active,
                'key_check_values' => $kcv,
            ]);
        });

        $this->info("Key set {$version} is active. Key check values:");
        $this->table(['Key', 'KCV'], array_map(null, array_keys($kcv), array_values($kcv)));
        $this->warn('Back up the keystore file now (encrypted with CRYPTO_KEYSTORE_KEY); without it no card of this set can be verified.');

        return self::SUCCESS;
    }
}
