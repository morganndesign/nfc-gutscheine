<?php

declare(strict_types=1);

namespace App\Crypto;

/**
 * The only way the platform uses a secret key. Keys are named by a {@see KeyReference}; their material never
 * leaves the provider. Implementations: {@see Local\LocalCryptoProvider} (encrypted keystore file) now,
 * Google Cloud HSM or AWS CloudHSM later — business logic never knows which one runs.
 *
 * The operations are the raw block-cipher primitives every HSM offers (Cloud HSM raw AES-CBC, PKCS#11
 * CKM_AES_CBC). Everything built on top (CMAC, AN10922 diversification, SUN, EV2 authentication) lives in
 * provider-independent code.
 */
interface CryptoProvider
{
    /** Short name of the implementation ("local", …) for logs and health checks. */
    public function name(): string;

    public function has(KeyReference $key): bool;

    /**
     * AES-CBC encryption without padding.
     *
     * @param  string  $iv  16 bytes
     * @param  string  $data  a non-empty multiple of 16 bytes
     *
     * @throws Exceptions\KeyNotFoundException
     */
    public function encryptCbc(KeyReference $key, string $iv, string $data): string;

    /**
     * AES-CBC decryption without padding.
     *
     * @param  string  $iv  16 bytes
     * @param  string  $data  a non-empty multiple of 16 bytes
     *
     * @throws Exceptions\KeyNotFoundException
     */
    public function decryptCbc(KeyReference $key, string $iv, string $data): string;

    /** Key check value: the first 3 bytes of AES(key, 0¹²⁸), upper-case hex. Identifies a key without revealing it. */
    public function keyCheckValue(KeyReference $key): string;
}
