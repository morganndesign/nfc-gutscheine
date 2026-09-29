<?php

declare(strict_types=1);

namespace Tests\Unit\Crypto;

use App\Crypto\KeyReference;
use App\Crypto\Primitives\Cmac;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/** RFC 4493 §4 known answers, with a software key and with a provider-held key. */
final class CmacTest extends TestCase
{
    private const KEY = '2b7e151628aed2a6abf7158809cf4f3c';

    /** @return iterable<string, array{string, string}> */
    public static function vectors(): iterable
    {
        yield 'empty' => ['', 'bb1d6929e95937287fa37d129b756746'];
        yield '16 bytes' => ['6bc1bee22e409f96e93d7e117393172a', '070a16b46b4d4144f79bdd9dd04a287c'];
        yield '40 bytes' => ['6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411', 'dfa66747de9ae63030ca32611497c827'];
        yield '64 bytes' => ['6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710', '51f0bebf7e3b9d92fc49741779363cfe'];
    }

    #[DataProvider('vectors')]
    public function test_rfc4493_with_a_software_key(string $messageHex, string $expected): void
    {
        $this->assertSame($expected, bin2hex(Cmac::compute((string) hex2bin(self::KEY), (string) hex2bin($messageHex))));
    }

    #[DataProvider('vectors')]
    public function test_rfc4493_with_a_provider_key(string $messageHex, string $expected): void
    {
        $provider = InMemoryProvider::with(['test/cmac' => self::KEY]);

        $this->assertSame($expected, bin2hex(Cmac::withProvider($provider, new KeyReference('test/cmac'), (string) hex2bin($messageHex))));
    }
}
