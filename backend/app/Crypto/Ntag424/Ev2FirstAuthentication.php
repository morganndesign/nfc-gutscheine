<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use App\Crypto\Primitives\Aes;
use App\Crypto\Primitives\Cmac;
use App\Exceptions\Domain\CardAuthenticationFailedException;
use InvalidArgumentException;

/**
 * AuthenticateEV2First (NTAG 424 DNA, NXP AN12196 §3.6) from the server's side (the PCD), with the card's key
 * as an ephemeral key. The phone only relays the bytes.
 *
 * 1. Card → E(K, RndB).  {@see self::respond()} returns E(K, RndA ‖ RndB'), keeping RndA on the server.
 * 2. Card → E(K, TI ‖ RndA' ‖ PDcap2 ‖ PCDcap2).  {@see self::complete()} checks RndA' and derives the session keys.
 */
final class Ev2FirstAuthentication
{
    /**
     * @return array{rndA: string, rndB: string, response: string} response = E(K, RndA ‖ RndB') for the card
     */
    public static function respond(string $key, string $encryptedRndB, ?string $rndA = null): array
    {
        if (strlen($encryptedRndB) !== 16) {
            throw new InvalidArgumentException('The card challenge E(K, RndB) is 16 bytes.');
        }
        $rndA ??= random_bytes(16);
        $rndB = Aes::decryptCbc($key, Aes::ZERO_IV, $encryptedRndB);

        return [
            'rndA' => $rndA,
            'rndB' => $rndB,
            'response' => Aes::encryptCbc($key, Aes::ZERO_IV, $rndA.self::rotate($rndB)),
        ];
    }

    public static function complete(string $key, string $rndA, string $rndB, string $encryptedCardResponse): Ev2Session
    {
        if (strlen($encryptedCardResponse) !== 32) {
            throw new CardAuthenticationFailedException;
        }
        $plain = Aes::decryptCbc($key, Aes::ZERO_IV, $encryptedCardResponse);
        if (! hash_equals(self::rotate($rndA), substr($plain, 4, 16))) {
            throw new CardAuthenticationFailedException;
        }

        // SV1/SV2 = A5 5A|5A A5 ‖ 00 01 00 80 ‖ RndA[15..14] ‖ (RndA[13..8] ⊕ RndB[15..10]) ‖ RndB[9..0] ‖ RndA[7..0]
        $context = substr($rndA, 0, 2).(substr($rndA, 2, 6) ^ substr($rndB, 0, 6)).substr($rndB, 6, 10).substr($rndA, 8, 8);

        return new Ev2Session(
            transactionId: substr($plain, 0, 4),
            encryptionKey: Cmac::compute($key, "\xA5\x5A\x00\x01\x00\x80".$context),
            macKey: Cmac::compute($key, "\x5A\xA5\x00\x01\x00\x80".$context),
            pdCap2: substr($plain, 20, 6),
            pcdCap2: substr($plain, 26, 6),
        );
    }

    /** RndX' = RndX rotated left by one byte. */
    public static function rotate(string $random): string
    {
        return substr($random, 1).$random[0];
    }
}
