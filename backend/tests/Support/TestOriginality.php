<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Crypto\Ntag424\OriginalitySignature as Sig;

/**
 * A stand-in for NXP's signing key: simulated chips carry an ECDSA secp224r1 signature of their UID under this
 * test key, and tests point the server at its public key. A chip without it (or signed by another key) is a fake.
 */
final class TestOriginality
{
    private static ?string $private = null;

    public static function publicKey(): string
    {
        $q = Sig::multiply(self::privateKey(), Sig::generator()) ?? throw new \LogicException('Point at infinity.');

        return strtoupper('04'.Sig::hex($q[0], 28).Sig::hex($q[1], 28));
    }

    public static function sign(string $uid): string
    {
        $n = Sig::order();
        $e = Sig::dec(bin2hex($uid));
        do {
            $k = Sig::mod(Sig::dec(bin2hex(random_bytes(28))), $n);
            $point = Sig::multiply($k, Sig::generator());
            $r = $point === null ? '0' : Sig::mod($point[0], $n);
            $s = Sig::mod(bcmul(Sig::inverse($k, $n), bcadd($e, bcmul($r, self::privateKey()))), $n);
        } while ($r === '0' || $s === '0');

        return (string) hex2bin(Sig::hex($r, 28).Sig::hex($s, 28));
    }

    private static function privateKey(): string
    {
        return self::$private ??= Sig::mod(Sig::dec(bin2hex(random_bytes(28))), Sig::order());
    }
}
