<?php

declare(strict_types=1);

namespace App\Providers;

use App\Crypto\CryptoProvider;
use App\Crypto\Exceptions\KeystoreException;
use App\Crypto\Local\LocalCryptoProvider;
use App\Crypto\Local\LocalKeystore;
use Illuminate\Support\ServiceProvider;

/**
 * Binds the one {@see CryptoProvider} of this installation. Switching to an HSM provider is a new case here and
 * a configuration change; nothing else in the application changes.
 */
final class CryptoServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(LocalKeystore::class, static fn (): LocalKeystore => new LocalKeystore(
            (string) config('crypto.local.keystore_path'),
            LocalKeystore::decodeMasterKey(config('crypto.local.master_key')),
        ));

        $this->app->singleton(CryptoProvider::class, fn (): CryptoProvider => match (config('crypto.provider')) {
            'local' => new LocalCryptoProvider($this->app->make(LocalKeystore::class)),
            default => throw new KeystoreException(sprintf('Unknown crypto provider "%s" (CRYPTO_PROVIDER).', (string) config('crypto.provider'))),
        });
    }
}
