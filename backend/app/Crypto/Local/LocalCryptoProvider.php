<?php

declare(strict_types=1);

namespace App\Crypto\Local;

use App\Crypto\CryptoProvider;
use App\Crypto\Exceptions\KeyNotFoundException;
use App\Crypto\KeyReference;
use App\Crypto\Primitives\Aes;

/**
 * Keys from one encrypted keystore file ({@see LocalKeystore}), opened once per process with the master key
 * from the environment. The material stays inside this object; callers only get the results of operations.
 */
final class LocalCryptoProvider implements CryptoProvider
{
    /** @var array<string, string>|null reference => 16-byte key */
    private ?array $keys = null;

    public function __construct(private readonly LocalKeystore $keystore) {}

    public function name(): string
    {
        return 'local';
    }

    public function has(KeyReference $key): bool
    {
        return isset($this->keys()[$key->name]);
    }

    public function encryptCbc(KeyReference $key, string $iv, string $data): string
    {
        return Aes::encryptCbc($this->material($key), $iv, $data);
    }

    public function decryptCbc(KeyReference $key, string $iv, string $data): string
    {
        return Aes::decryptCbc($this->material($key), $iv, $data);
    }

    public function keyCheckValue(KeyReference $key): string
    {
        return LocalKeystore::kcv($this->material($key));
    }

    private function material(KeyReference $key): string
    {
        return $this->keys()[$key->name] ?? throw KeyNotFoundException::for($key);
    }

    /** @return array<string, string> */
    private function keys(): array
    {
        return $this->keys ??= array_map(static fn (array $entry): string => $entry['material'], $this->keystore->read());
    }

    /** Never print key material, whatever dumps this object. */
    public function __debugInfo(): array
    {
        return ['provider' => 'local', 'keystore' => $this->keystore->path(), 'loaded' => $this->keys !== null];
    }
}
