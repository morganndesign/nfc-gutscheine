<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use InvalidArgumentException;

/**
 * NXP originality check (NT4H2421Gx §9.3, AN12196 §7): every genuine NTAG 424 DNA carries an ECDSA signature of
 * its 7-byte UID (not hashed) on secp224r1 by NXP, read with Read_Sig (`90 3C 00 00 01 00 00`). A chip that is not
 * an NXP NTAG 424 DNA (an emulator, a clone of another type) cannot produce it.
 *
 * Plain ECDSA verification with bcmath (Jacobian coordinates); it runs once per chip at the station.
 *
 * @phpstan-type Point array{0: numeric-string, 1: numeric-string}
 * @phpstan-type Jacobian array{0: numeric-string, 1: numeric-string, 2: numeric-string}
 */
final class OriginalitySignature
{
    /** The NXP public key for NTAG 424 DNA (uncompressed SEC1 point), AN12196. */
    public const NXP_PUBLIC_KEY = '048A9B380AF2EE1B98DC417FECC263F8449C7625CECE82D9B916C992DA209D68422B81EC20B65A66B5102A61596AF3379200599316A00A1410';

    private const P = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000001';

    private const A = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFE';

    private const B = 'B4050A850C04B3ABF54132565044B0B7D7BFD8BA270B39432355FFB4';

    private const GX = 'B70E0CBD6BB4BF7F321390B94A03C1D356C21122343280D6115C1D21';

    private const GY = 'BD376388B5F723FB4C22DFE6CD4375A05A07476444D5819985007E34';

    private const N = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFF16A2E0B8F03E13DD29455C5C2A3D';

    /**
     * @param  string  $uid  7 raw bytes
     * @param  string  $signature  56 raw bytes: r ‖ s
     * @param  string|null  $publicKeyHex  uncompressed point; the NXP key unless given
     */
    public static function verify(string $uid, string $signature, ?string $publicKeyHex = null): bool
    {
        if (strlen($uid) !== 7 || strlen($signature) !== 56) {
            return false;
        }
        $n = self::constant(self::N);
        $r = self::dec(bin2hex(substr($signature, 0, 28)));
        $s = self::dec(bin2hex(substr($signature, 28, 28)));
        if (bccomp($r, '1') < 0 || bccomp($r, $n) >= 0 || bccomp($s, '1') < 0 || bccomp($s, $n) >= 0) {
            return false;
        }
        $q = self::point($publicKeyHex ?? self::NXP_PUBLIC_KEY);
        if ($q === null) {
            return false;
        }

        $e = self::dec(bin2hex($uid));
        $w = self::inverse($s, $n);
        $u1 = self::mod(bcmul($e, $w), $n);
        $u2 = self::mod(bcmul($r, $w), $n);
        $g = self::generator();
        $x = self::affine(self::addJacobian(self::multiplyJacobian($u1, [$g[0], $g[1], '1']), self::multiplyJacobian($u2, [$q[0], $q[1], '1'])));
        if ($x === null) {
            return false;
        }

        return bccomp(self::mod($x[0], $n), $r) === 0;
    }

    /**
     * Scalar multiple of a point (double-and-add in Jacobian coordinates, one inversion at the end). Public for the
     * station's test chips, which sign with a test key: `multiply(d, generator())` is a public key.
     *
     * @param  numeric-string  $k
     * @param  Point|null  $point
     * @return Point|null
     */
    public static function multiply(string $k, ?array $point): ?array
    {
        return self::affine(self::multiplyJacobian($k, $point === null ? null : [$point[0], $point[1], '1']));
    }

    /**
     * @param  numeric-string  $k
     * @param  Jacobian|null  $point
     * @return Jacobian|null
     */
    private static function multiplyJacobian(string $k, ?array $point): ?array
    {
        $result = null;
        $addend = $point;
        while (bccomp($k, '0') > 0 && $addend !== null) {
            if (bcmod($k, '2') === '1') {
                $result = self::addJacobian($result, $addend);
            }
            $addend = self::doubleJacobian($addend);
            $k = bcdiv($k, '2', 0);
        }

        return $result;
    }

    /** @return Point */
    public static function generator(): array
    {
        return [self::dec(self::GX), self::dec(self::GY)];
    }

    /** @return numeric-string */
    public static function order(): string
    {
        return self::constant(self::N);
    }

    /** @return numeric-string */
    private static function constant(string $hex): string
    {
        static $cache = [];

        return $cache[$hex] ??= self::dec($hex);
    }

    /**
     * Big-endian hex → decimal string.
     *
     * @return numeric-string
     */
    public static function dec(string $hex): string
    {
        $dec = '0';
        foreach (str_split(strtolower($hex)) as $digit) {
            $dec = bcadd(bcmul($dec, '16'), (string) hexdec($digit));
        }

        return $dec;
    }

    /**
     * Decimal string → big-endian hex of `$bytes` bytes.
     *
     * @param  numeric-string  $dec
     */
    public static function hex(string $dec, int $bytes): string
    {
        $hex = '';
        while (bccomp($dec, '0') > 0) {
            $hex = dechex((int) bcmod($dec, '16')).$hex;
            $dec = bcdiv($dec, '16', 0);
        }
        if (strlen($hex) > $bytes * 2) {
            throw new InvalidArgumentException('Value too large.');
        }

        return str_pad($hex, $bytes * 2, '0', STR_PAD_LEFT);
    }

    /**
     * @param  numeric-string  $a
     * @param  numeric-string  $m
     * @return numeric-string
     */
    public static function inverse(string $a, string $m): string
    {
        // Fermat: m is prime (p and n of secp224r1 are).
        return bcpowmod(self::mod($a, $m), bcsub($m, '2'), $m);
    }

    /**
     * @param  numeric-string  $a
     * @param  numeric-string  $m
     * @return numeric-string
     */
    public static function mod(string $a, string $m): string
    {
        $r = bcmod($a, $m);

        return bccomp($r, '0') < 0 ? bcadd($r, $m) : $r;
    }

    /** @return Point|null the point, when it is on the curve */
    private static function point(string $hex): ?array
    {
        if (preg_match('/^04[0-9A-Fa-f]{112}$/', $hex) !== 1) {
            return null;
        }
        $x = self::dec(substr($hex, 2, 56));
        $y = self::dec(substr($hex, 58, 56));
        $p = self::constant(self::P);
        $left = self::mod(bcmul($y, $y), $p);
        $right = self::mod(bcadd(bcadd(bcmul(bcmul($x, $x), $x), bcmul(self::constant(self::A), $x)), self::constant(self::B)), $p);

        return $left === $right ? [$x, $y] : null;
    }

    /**
     * @param  Jacobian|null  $a
     * @return Jacobian|null
     */
    private static function doubleJacobian(?array $a): ?array
    {
        if ($a === null || $a[1] === '0') {
            return null;
        }
        $p = self::constant(self::P);
        [$x, $y, $z] = $a;
        $yy = self::mod(bcmul($y, $y), $p);
        $s = self::mod(bcmul('4', bcmul($x, $yy)), $p);
        $zz = self::mod(bcmul($z, $z), $p);
        $m = self::mod(bcadd(bcmul('3', bcmul($x, $x)), bcmul(self::constant(self::A), self::mod(bcmul($zz, $zz), $p))), $p);
        $x3 = self::mod(bcsub(bcmul($m, $m), bcmul('2', $s)), $p);
        $y3 = self::mod(bcsub(bcmul($m, bcsub($s, $x3)), bcmul('8', self::mod(bcmul($yy, $yy), $p))), $p);
        $z3 = self::mod(bcmul('2', bcmul($y, $z)), $p);

        return [$x3, $y3, $z3];
    }

    /**
     * @param  Jacobian|null  $a
     * @param  Jacobian|null  $b
     * @return Jacobian|null
     */
    private static function addJacobian(?array $a, ?array $b): ?array
    {
        if ($a === null) {
            return $b;
        }
        if ($b === null) {
            return $a;
        }
        $p = self::constant(self::P);
        $z1z1 = self::mod(bcmul($a[2], $a[2]), $p);
        $z2z2 = self::mod(bcmul($b[2], $b[2]), $p);
        $u1 = self::mod(bcmul($a[0], $z2z2), $p);
        $u2 = self::mod(bcmul($b[0], $z1z1), $p);
        $s1 = self::mod(bcmul($a[1], self::mod(bcmul($b[2], $z2z2), $p)), $p);
        $s2 = self::mod(bcmul($b[1], self::mod(bcmul($a[2], $z1z1), $p)), $p);
        if ($u1 === $u2) {
            return $s1 === $s2 ? self::doubleJacobian($a) : null;
        }
        $h = self::mod(bcsub($u2, $u1), $p);
        $r = self::mod(bcsub($s2, $s1), $p);
        $hh = self::mod(bcmul($h, $h), $p);
        $hhh = self::mod(bcmul($h, $hh), $p);
        $v = self::mod(bcmul($u1, $hh), $p);
        $x3 = self::mod(bcsub(bcsub(bcmul($r, $r), $hhh), bcmul('2', $v)), $p);
        $y3 = self::mod(bcsub(bcmul($r, bcsub($v, $x3)), bcmul($s1, $hhh)), $p);
        $z3 = self::mod(bcmul($h, bcmul($a[2], $b[2])), $p);

        return [$x3, $y3, $z3];
    }

    /**
     * @param  Jacobian|null  $a
     * @return Point|null
     */
    private static function affine(?array $a): ?array
    {
        if ($a === null) {
            return null;
        }
        $p = self::constant(self::P);
        $zi = self::inverse($a[2], $p);
        $zi2 = self::mod(bcmul($zi, $zi), $p);

        return [self::mod(bcmul($a[0], $zi2), $p), self::mod(bcmul($a[1], self::mod(bcmul($zi2, $zi), $p)), $p)];
    }
}
