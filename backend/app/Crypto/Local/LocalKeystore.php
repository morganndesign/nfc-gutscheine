<?php

declare(strict_types=1);

namespace App\Crypto\Local;

use App\Crypto\Exceptions\KeystoreException;
use App\Crypto\KeyReference;
use App\Crypto\Primitives\Aes;
use Illuminate\Support\Carbon;
use JsonException;
use SensitiveParameter;

/**
 * One encrypted file holding every key of the {@see LocalCryptoProvider}: the whole key list is sealed with
 * AES-256-GCM under a 32-byte master key that only ever comes from the environment. A changed, truncated or
 * swapped file fails authentication; nothing is readable without the master key.
 *
 * File: {"format":"giftcard-pro-keystore","version":1,"cipher":"aes-256-gcm","iv":…,"tag":…,"ciphertext":…}
 * Plaintext: {"keys":{"<reference>":{"algorithm":"aes-128","material":<base64>,"kcv":"ABCDEF","created_at":…}}}
 *
 * Reading is for the provider; writing (create, add, re-key) is for the operator commands only.
 */
final class LocalKeystore
{
    public const FORMAT = 'giftcard-pro-keystore';

    public const VERSION = 1;

    private const AAD = 'giftcard-pro-keystore/v1';

    public function __construct(
        private readonly string $path,
        #[SensitiveParameter] private readonly string $masterKey,
    ) {
        if (strlen($masterKey) !== 32) {
            throw new KeystoreException('The keystore master key must be 32 bytes (CRYPTO_KEYSTORE_KEY=base64:… from `openssl rand -base64 32`).');
        }
    }

    /** Parses `base64:…` (or plain base64) into the 32-byte master key. */
    public static function decodeMasterKey(#[SensitiveParameter] ?string $value): string
    {
        $value = trim((string) $value);
        if ($value === '') {
            throw new KeystoreException('CRYPTO_KEYSTORE_KEY is not set.');
        }
        $raw = base64_decode(str_starts_with($value, 'base64:') ? substr($value, 7) : $value, true);
        if ($raw === false || strlen($raw) !== 32) {
            throw new KeystoreException('CRYPTO_KEYSTORE_KEY must be base64 of 32 random bytes.');
        }

        return $raw;
    }

    public function exists(): bool
    {
        return is_file($this->path);
    }

    public function path(): string
    {
        return $this->path;
    }

    /**
     * @return array<string, array{algorithm: string, material: string, kcv: string, created_at: string}> reference => entry, material raw bytes
     */
    public function read(): array
    {
        if (! $this->exists()) {
            throw new KeystoreException("The keystore {$this->path} does not exist (run `php artisan crypto:keystore:init`).");
        }

        try {
            /** @var array<string, mixed> $file */
            $file = json_decode((string) file_get_contents($this->path), true, 8, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new KeystoreException('The keystore file is not readable.');
        }
        if (($file['format'] ?? null) !== self::FORMAT || ($file['version'] ?? null) !== self::VERSION || ($file['cipher'] ?? null) !== 'aes-256-gcm') {
            throw new KeystoreException('The keystore file has an unknown format.');
        }

        $iv = base64_decode((string) ($file['iv'] ?? ''), true);
        $tag = base64_decode((string) ($file['tag'] ?? ''), true);
        $ciphertext = base64_decode((string) ($file['ciphertext'] ?? ''), true);
        if ($iv === false || $tag === false || $ciphertext === false || strlen($iv) !== 12 || strlen($tag) !== 16) {
            throw new KeystoreException('The keystore file is damaged.');
        }

        $plain = openssl_decrypt($ciphertext, 'aes-256-gcm', $this->masterKey, OPENSSL_RAW_DATA, $iv, $tag, self::AAD);
        if ($plain === false) {
            throw new KeystoreException('The keystore cannot be opened: wrong master key, or the file was changed.');
        }

        try {
            /** @var array{keys: array<string, array{algorithm: string, material: string, kcv: string, created_at: string}>} $data */
            $data = json_decode($plain, true, 8, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new KeystoreException('The keystore content is not readable.');
        }

        $keys = [];
        foreach ($data['keys'] as $reference => $entry) {
            $material = base64_decode($entry['material'], true);
            if ($material === false || strlen($material) !== 16 || $entry['algorithm'] !== 'aes-128') {
                throw new KeystoreException("The keystore entry {$reference} is invalid.");
            }
            if (self::kcv($material) !== $entry['kcv']) {
                throw new KeystoreException("The keystore entry {$reference} does not match its key check value.");
            }
            $keys[$reference] = ['algorithm' => 'aes-128', 'material' => $material, 'kcv' => $entry['kcv'], 'created_at' => $entry['created_at']];
        }

        return $keys;
    }

    /** Creates an empty keystore. Refuses to overwrite an existing one. */
    public function create(): void
    {
        if ($this->exists()) {
            throw new KeystoreException("The keystore {$this->path} already exists.");
        }
        $this->write([]);
    }

    /**
     * Adds a key. Refuses to replace an existing reference: a key set is never changed, a new one is created.
     *
     * @return string the key check value
     */
    public function add(KeyReference $reference, #[SensitiveParameter] string $material): string
    {
        if (strlen($material) !== 16) {
            throw new KeystoreException('Only AES-128 keys (16 bytes) are held.');
        }
        $keys = $this->read();
        if (isset($keys[$reference->name])) {
            throw new KeystoreException("The keystore already holds {$reference}; keys are never replaced.");
        }
        $kcv = self::kcv($material);
        $keys[$reference->name] = ['algorithm' => 'aes-128', 'material' => $material, 'kcv' => $kcv, 'created_at' => Carbon::now()->toIso8601String()];
        $this->write($keys);

        return $kcv;
    }

    /** Re-encrypts the whole keystore under a new master key. */
    public function rekey(#[SensitiveParameter] string $newMasterKey): self
    {
        $keys = $this->read();
        $next = new self($this->path, $newMasterKey);
        $next->write($keys);

        return $next;
    }

    public static function kcv(#[SensitiveParameter] string $material): string
    {
        return strtoupper(bin2hex(substr(Aes::encryptBlock($material, str_repeat("\0", Aes::BLOCK)), 0, 3)));
    }

    /** @param array<string, array{algorithm: string, material: string, kcv: string, created_at: string}> $keys */
    private function write(array $keys): void
    {
        $plain = json_encode(['keys' => array_map(static fn (array $entry): array => [
            'algorithm' => $entry['algorithm'],
            'material' => base64_encode($entry['material']),
            'kcv' => $entry['kcv'],
            'created_at' => $entry['created_at'],
        ], $keys) ?: new \stdClass], JSON_THROW_ON_ERROR);

        $iv = random_bytes(12);
        $tag = '';
        $ciphertext = openssl_encrypt($plain, 'aes-256-gcm', $this->masterKey, OPENSSL_RAW_DATA, $iv, $tag, self::AAD, 16);
        if ($ciphertext === false) {
            throw new KeystoreException('The keystore could not be encrypted.');
        }

        $directory = dirname($this->path);
        if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
            throw new KeystoreException("The keystore directory {$directory} cannot be created.");
        }

        // Written next to the target and renamed: a crash never leaves half a keystore.
        $temporary = $this->path.'.'.bin2hex(random_bytes(4)).'.tmp';
        $json = json_encode([
            'format' => self::FORMAT,
            'version' => self::VERSION,
            'cipher' => 'aes-256-gcm',
            'iv' => base64_encode($iv),
            'tag' => base64_encode($tag),
            'ciphertext' => base64_encode($ciphertext),
        ], JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR);
        if (file_put_contents($temporary, $json."\n", LOCK_EX) === false || ! chmod($temporary, 0600) || ! rename($temporary, $this->path)) {
            @unlink($temporary);
            throw new KeystoreException("The keystore {$this->path} cannot be written.");
        }
    }
}
