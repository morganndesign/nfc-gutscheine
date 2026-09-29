<?php

declare(strict_types=1);

namespace Tests\Unit\Crypto;

use App\Crypto\Ntag424\OriginalitySignature;
use PHPUnit\Framework\TestCase;

/** The NXP originality signature against the AN12196 example chip. */
final class OriginalitySignatureTest extends TestCase
{
    private const UID = '04518DFAA96180';

    private const SIGNATURE = 'D1940D17CFEDA4BFF80359AB975F9F6514313E8F90C1D3CAAF5941AD744A1CDF9A83F883CAFE0FE95D1939B1B7E47113993324473B785D21';

    public function test_the_an12196_chip_is_genuine(): void
    {
        $this->assertTrue(OriginalitySignature::verify((string) hex2bin(self::UID), (string) hex2bin(self::SIGNATURE)));
    }

    public function test_another_uid_a_changed_signature_or_another_key_is_not(): void
    {
        $signature = (string) hex2bin(self::SIGNATURE);
        $this->assertFalse(OriginalitySignature::verify((string) hex2bin('04518DFAA96181'), $signature));
        $this->assertFalse(OriginalitySignature::verify((string) hex2bin(self::UID), substr($signature, 0, 55)."\x00"));
        $this->assertFalse(OriginalitySignature::verify((string) hex2bin(self::UID), str_repeat("\0", 56)));
        $this->assertFalse(OriginalitySignature::verify((string) hex2bin(self::UID), $signature, '04'.str_repeat('11', 56)));
        $this->assertFalse(OriginalitySignature::verify('short', $signature));
    }
}
