<?php

declare(strict_types=1);

namespace Tests\Unit\Crypto;

use App\Crypto\Exceptions\KeyNotFoundException;
use App\Crypto\Exceptions\KeystoreException;
use App\Crypto\KeyReference;
use App\Crypto\Local\LocalCryptoProvider;
use App\Crypto\Local\LocalKeystore;
use App\Crypto\Primitives\Aes;
use PHPUnit\Framework\TestCase;

final class LocalKeystoreTest extends TestCase
{
    private string $path;

    private string $master;

    protected function setUp(): void
    {
        $this->path = sys_get_temp_dir().'/gcp-ks-'.bin2hex(random_bytes(6)).'/keystore.json';
        $this->master = random_bytes(32);
    }

    protected function tearDown(): void
    {
        if (is_file($this->path)) {
            unlink($this->path);
        }
        if (is_dir(dirname($this->path))) {
            rmdir(dirname($this->path));
        }
    }

    public function test_keys_are_encrypted_at_rest_and_only_usable_through_the_provider(): void
    {
        $keystore = new LocalKeystore($this->path, $this->master);
        $keystore->create();
        $kcv = $keystore->add(new KeyReference('ks-1/sdm-meta-read'), str_repeat("\0", 16));

        $this->assertSame('66E94B', $kcv, 'KCV of the all-zero AES key');
        $this->assertSame('0600', substr(sprintf('%o', fileperms($this->path)), -4));
        $raw = (string) file_get_contents($this->path);
        $this->assertStringNotContainsString('ks-1/sdm-meta-read', $raw, 'not even the names are readable');
        $this->assertStringNotContainsString(base64_encode(str_repeat("\0", 16)), $raw);

        $provider = new LocalCryptoProvider(new LocalKeystore($this->path, $this->master));
        $reference = new KeyReference('ks-1/sdm-meta-read');
        $this->assertTrue($provider->has($reference));
        $this->assertSame('66E94B', $provider->keyCheckValue($reference));
        $this->assertSame('66E94BD4EF8A2C3B884CFA59CA342B2E', strtoupper(bin2hex($provider->encryptCbc($reference, Aes::ZERO_IV, str_repeat("\0", 16)))));
        $this->assertStringNotContainsString("\0\0\0\0\0\0\0\0", print_r($provider, true));

        $this->expectException(KeyNotFoundException::class);
        $provider->encryptCbc(new KeyReference('ks-1/unknown'), Aes::ZERO_IV, str_repeat("\0", 16));
    }

    public function test_a_wrong_master_key_or_a_changed_file_fails_closed(): void
    {
        $keystore = new LocalKeystore($this->path, $this->master);
        $keystore->create();
        $keystore->add(new KeyReference('ks-1/a'), random_bytes(16));

        try {
            (new LocalKeystore($this->path, random_bytes(32)))->read();
            $this->fail('Opened with a wrong master key.');
        } catch (KeystoreException) {
            $this->addToAssertionCount(1);
        }

        $file = json_decode((string) file_get_contents($this->path), true);
        $cipher = base64_decode($file['ciphertext']);
        $cipher[5] = chr(ord($cipher[5]) ^ 1);
        $file['ciphertext'] = base64_encode($cipher);
        file_put_contents($this->path, json_encode($file));

        $this->expectException(KeystoreException::class);
        $keystore->read();
    }

    public function test_keys_are_never_replaced_and_the_master_key_can_be_rotated(): void
    {
        $keystore = new LocalKeystore($this->path, $this->master);
        $keystore->create();
        $keystore->add(new KeyReference('ks-1/a'), str_repeat("\1", 16));

        try {
            $keystore->add(new KeyReference('ks-1/a'), str_repeat("\2", 16));
            $this->fail('A key was replaced.');
        } catch (KeystoreException) {
            $this->addToAssertionCount(1);
        }

        $newMaster = random_bytes(32);
        $keystore->rekey($newMaster);
        $this->assertSame(LocalKeystore::kcv(str_repeat("\1", 16)), (new LocalKeystore($this->path, $newMaster))->read()['ks-1/a']['kcv']);

        $this->expectException(KeystoreException::class);
        $keystore->read();
    }

    public function test_the_master_key_must_be_32_random_bytes_in_base64(): void
    {
        $this->assertSame(32, strlen(LocalKeystore::decodeMasterKey('base64:'.base64_encode(random_bytes(32)))));

        foreach ([null, '', 'base64:'.base64_encode('short'), 'not base64 at all!'] as $value) {
            try {
                LocalKeystore::decodeMasterKey($value);
                $this->fail('Accepted '.var_export($value, true));
            } catch (KeystoreException) {
                $this->addToAssertionCount(1);
            }
        }
    }
}
