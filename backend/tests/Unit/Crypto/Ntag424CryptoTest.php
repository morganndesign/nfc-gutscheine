<?php

declare(strict_types=1);

namespace Tests\Unit\Crypto;

use App\Crypto\KeyReference;
use App\Crypto\Ntag424\An10922;
use App\Crypto\Ntag424\Ev2FirstAuthentication;
use App\Crypto\Ntag424\SunVerifier;
use App\Crypto\Primitives\Aes;
use App\Exceptions\Domain\CardAuthenticationFailedException;
use App\Exceptions\Domain\SunVerificationFailedException;
use PHPUnit\Framework\TestCase;

/** NXP reference vectors (AN10922 §2.2.1, AN12196) against the provider-backed implementation. */
final class Ntag424CryptoTest extends TestCase
{
    public function test_an10922_aes128_reference_vector(): void
    {
        $provider = InMemoryProvider::with(['test/master' => '00112233445566778899AABBCCDDEEFF']);
        $input = (string) hex2bin('04782E21801D80'.'3042F5'.'4E585020416275');

        $this->assertSame('A8DD63A3B89D54B37CA802473FDA9175', strtoupper(bin2hex(An10922::fromProvider($provider, new KeyReference('test/master'), $input))));
        $this->assertSame('A8DD63A3B89D54B37CA802473FDA9175', strtoupper(bin2hex(An10922::fromKey((string) hex2bin('00112233445566778899AABBCCDDEEFF'), $input))));
    }

    public function test_an10922_full_32_byte_input_uses_k1(): void
    {
        // 31 bytes of input + the 0x01 prefix fill two blocks: no padding, subkey K1 (a different code path).
        $key = (string) hex2bin('00112233445566778899AABBCCDDEEFF');
        $this->assertNotSame(An10922::fromKey($key, str_repeat("\x11", 30)), An10922::fromKey($key, str_repeat("\x11", 31)));
        $this->assertSame(16, strlen(An10922::fromKey($key, str_repeat("\x11", 31))));
    }

    public function test_sun_an12196_reference_vector(): void
    {
        $zero = str_repeat("\0", 16);

        $message = SunVerifier::verify($zero, static fn (string $uid): string => $zero, 'EF963FF7828658A599F3041510671E88', '94EED9EE65337086');

        $this->assertSame('04DE5F1EACC040', $message->uid);
        $this->assertSame(61, $message->readCounter);
    }

    public function test_sun_with_non_zero_keys_and_little_endian_counters(): void
    {
        $file = (string) hex2bin('f0e1d2c3b4a5968778695a4b3c2d1e0f');
        $meta = (string) hex2bin('0f1e2d3c4b5a69788796a5b4c3d2e1f0');
        $key = static fn (string $uid): string => $file;

        $max = SunVerifier::verify($meta, $key, '60fcf1396f08fdca4a261e49b42c5fbb', '9a60324f845d7684');
        $this->assertSame('04A39493CC8680', $max->uid);
        $this->assertSame(0xFFFFFF, $max->readCounter);
        $this->assertSame(1, SunVerifier::verify($meta, $key, 'ad12752466e17f121a6f56fcdf5bffb0', 'a7e44bf982933c3d')->readCounter);
        $this->assertSame(65536, SunVerifier::verify($meta, $key, 'da78eed24789833a0f1c0a98d8e44337', 'abb9b5c0ec0273d7')->readCounter);

        foreach ([
            ['60fcf1396f08fdca4a261e49b42c5fbb', '9b60324f845d7684'], // corrupted MAC
            ['da78eed24789833a0f1c0a98d8e44337', 'a7e44bf982933c3d'], // MAC of another counter
            ['af539b7388d4f796c70b01ea69d12e2e', '7980fea08da0721e'], // invalid PICC tag
            ['zz', '00'],                                             // not hex
        ] as [$e, $m]) {
            try {
                SunVerifier::verify($meta, $key, $e, $m);
                $this->fail("Accepted e={$e} m={$m}");
            } catch (SunVerificationFailedException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    public function test_ev2_first_authentication_reference_values(): void
    {
        $key = str_repeat("\0", 16);
        $rndA = (string) hex2bin('13C5DB8A5930439FC3DEF9A4C675360F');

        $step = Ev2FirstAuthentication::respond($key, (string) hex2bin('A04C124213C186F22399D33AC2A30215'), $rndA);
        $this->assertSame('B9E2FC789B64BF237CCCAA20EC7E6E48', strtoupper(bin2hex($step['rndB'])));
        $this->assertSame('35C3E05A752E0144BAC0DE51C1F22C56B34408A23D8AEA266CAB947EA8E0118D', strtoupper(bin2hex($step['response'])));

        // The card's answer: E(K, TI ‖ RndA' ‖ PDcap2 ‖ PCDcap2).
        $card = Aes::encryptCbc($key, Aes::ZERO_IV, hex2bin('9D00C4DF').Ev2FirstAuthentication::rotate($rndA).str_repeat("\0", 12));
        $session = Ev2FirstAuthentication::complete($key, $step['rndA'], $step['rndB'], $card);

        $this->assertSame('9D00C4DF', strtoupper(bin2hex($session->transactionId)));
        $this->assertSame('1309C877509E5A215007FF0ED19CA564', strtoupper(bin2hex($session->encryptionKey)));
        $this->assertSame('4C6626F5E72EA694202139295C7A7FC7', strtoupper(bin2hex($session->macKey)));
        $this->assertStringNotContainsString('1309C877', print_r($session, true), 'session keys never appear in dumps');
    }

    public function test_ev2_rejects_a_card_that_does_not_know_the_key(): void
    {
        $key = str_repeat("\0", 16);
        $step = Ev2FirstAuthentication::respond($key, random_bytes(16));
        $forged = Aes::encryptCbc(str_repeat("\1", 16), Aes::ZERO_IV, random_bytes(4).Ev2FirstAuthentication::rotate($step['rndA']).str_repeat("\0", 12));

        $this->expectException(CardAuthenticationFailedException::class);
        Ev2FirstAuthentication::complete($key, $step['rndA'], $step['rndB'], $forged);
    }
}
