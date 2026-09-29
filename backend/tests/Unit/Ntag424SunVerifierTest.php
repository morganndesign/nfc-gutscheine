<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Exceptions\Domain\SunVerificationFailedException;
use App\Services\Nfc\Ntag424SunVerifier;
use PHPUnit\Framework\TestCase;

/**
 * Vectors from NXP AN12196 (§3.4) and independent cross-implementation SDM vectors.
 */
final class Ntag424SunVerifierTest extends TestCase
{
    public function test_an12196_reference_vector(): void
    {
        $verifier = new Ntag424SunVerifier(str_repeat('0', 32), str_repeat('0', 32), false);

        $message = $verifier->verify('EF963FF7828658A599F3041510671E88', '94EED9EE65337086');

        $this->assertSame('04DE5F1EACC040', $message->uid);
        $this->assertSame(61, $message->readCounter);
    }

    public function test_non_zero_keys_and_max_counter(): void
    {
        $verifier = new Ntag424SunVerifier('0f1e2d3c4b5a69788796a5b4c3d2e1f0', 'f0e1d2c3b4a5968778695a4b3c2d1e0f', false);

        $message = $verifier->verify('60fcf1396f08fdca4a261e49b42c5fbb', '9a60324f845d7684');

        $this->assertSame('04A39493CC8680', $message->uid);
        $this->assertSame(0xFFFFFF, $message->readCounter);
    }

    public function test_counter_is_little_endian(): void
    {
        $verifier = new Ntag424SunVerifier('0f1e2d3c4b5a69788796a5b4c3d2e1f0', 'f0e1d2c3b4a5968778695a4b3c2d1e0f', false);

        $this->assertSame(1, $verifier->verify('ad12752466e17f121a6f56fcdf5bffb0', 'a7e44bf982933c3d')->readCounter);
        $this->assertSame(65536, $verifier->verify('da78eed24789833a0f1c0a98d8e44337', 'abb9b5c0ec0273d7')->readCounter);
    }

    public function test_corrupted_mac_is_rejected(): void
    {
        $verifier = new Ntag424SunVerifier('0f1e2d3c4b5a69788796a5b4c3d2e1f0', 'f0e1d2c3b4a5968778695a4b3c2d1e0f', false);

        $this->expectException(SunVerificationFailedException::class);
        $verifier->verify('60fcf1396f08fdca4a261e49b42c5fbb', '9b60324f845d7684');
    }

    public function test_mac_of_other_counter_is_rejected(): void
    {
        $verifier = new Ntag424SunVerifier('0f1e2d3c4b5a69788796a5b4c3d2e1f0', 'f0e1d2c3b4a5968778695a4b3c2d1e0f', false);

        $this->expectException(SunVerificationFailedException::class);
        $verifier->verify('da78eed24789833a0f1c0a98d8e44337', 'a7e44bf982933c3d');
    }

    public function test_invalid_picc_tag_is_rejected(): void
    {
        $verifier = new Ntag424SunVerifier('0f1e2d3c4b5a69788796a5b4c3d2e1f0', 'f0e1d2c3b4a5968778695a4b3c2d1e0f', false);

        $this->expectException(SunVerificationFailedException::class);
        $verifier->verify('af539b7388d4f796c70b01ea69d12e2e', '7980fea08da0721e');
    }

    public function test_missing_keys_are_reported(): void
    {
        $verifier = new Ntag424SunVerifier(null, null);

        $this->assertFalse($verifier->isConfigured());
        $this->expectException(SunVerificationFailedException::class);
        $verifier->verify('EF963FF7828658A599F3041510671E88', '94EED9EE65337086');
    }

    public function test_diversified_keys_change_the_mac(): void
    {
        $plain = new Ntag424SunVerifier(str_repeat('0', 32), str_repeat('0', 32), false);
        $diversified = new Ntag424SunVerifier(str_repeat('0', 32), str_repeat('0', 32), true);
        $uid = (string) hex2bin('04DE5F1EACC040');
        $counter = (string) hex2bin('3D0000');

        $this->assertSame('94EED9EE65337086', $plain->computeMac($uid, $counter));
        $this->assertNotSame($plain->computeMac($uid, $counter), $diversified->computeMac($uid, $counter));
    }
}
