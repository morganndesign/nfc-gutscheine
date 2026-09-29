<?php

declare(strict_types=1);

namespace Tests\Unit\Crypto;

use App\Crypto\Ntag424\CardProfile;
use App\Crypto\Ntag424\Ev2Session;
use App\Crypto\Ntag424\SecureMessaging;
use PHPUnit\Framework\TestCase;

/** EV2 secure messaging against the NXP AN12196 examples (ChangeFileSettings, ChangeKey). */
final class SecureMessagingTest extends TestCase
{
    private function session(string $enc, string $mac, string $ti): Ev2Session
    {
        return new Ev2Session((string) hex2bin($ti), (string) hex2bin($enc), (string) hex2bin($mac), str_repeat("\0", 6), str_repeat("\0", 6));
    }

    public function test_change_file_settings_an12196_example(): void
    {
        $messaging = SecureMessaging::resume($this->session('1309C877509E5A215007FF0ED19CA564', '4C6626F5E72EA694202139295C7A7FC7', '9D00C4DF'), 1);

        $apdu = $messaging->fullCommand(0x5F, "\x02", (string) hex2bin('4000E0C1F121200000430000430000'));

        $this->assertSame('905F0000190261B6D97903566E84C3AE5274467E89EAD799B7C1A0EF7A0400', strtoupper(bin2hex($apdu)));
        $this->assertSame('', $messaging->response((string) hex2bin('57BFF87B1241E93D9100')));
        $this->assertSame(2, $messaging->counter());
    }

    public function test_a_response_with_a_wrong_mac_or_status_is_refused(): void
    {
        $session = $this->session('1309C877509E5A215007FF0ED19CA564', '4C6626F5E72EA694202139295C7A7FC7', '9D00C4DF');

        $this->assertNull(SecureMessaging::resume($session, 1)->response((string) hex2bin('57BFF87B1241E93E9100')));
        $this->assertNull(SecureMessaging::resume($session, 1)->response((string) hex2bin('919D')));
        $this->assertNull(SecureMessaging::resume($session, 2)->response((string) hex2bin('57BFF87B1241E93D9100')));
    }

    public function test_change_key_data_and_nxp_crc32(): void
    {
        $new = (string) hex2bin('F3847D627727ED3BC9C4CC050489B966');

        $this->assertSame('789DFADC', strtoupper(bin2hex(CardProfile::crc32($new))));
        $this->assertSame(
            'F3847D627727ED3BC9C4CC050489B96601789DFADC800000000000000000000000',
            strtoupper(bin2hex(SecureMessaging::pad(CardProfile::changeKeyData(2, $new, CardProfile::FACTORY_KEY)))).'00',
        );
        $this->assertSame(32, strlen(SecureMessaging::pad(CardProfile::changeKeyData(2, $new, CardProfile::FACTORY_KEY))));
        $this->assertSame(32, strlen(SecureMessaging::pad(CardProfile::changeKeyData(0, $new))));
    }

    public function test_ndef_file_settings_follow_the_an12196_layout(): void
    {
        // AN12196 uses MetaRead K2, FileRead K1, CtrRet K1 (F121); the profile uses K1 / K2 and no counter read.
        $this->assertSame('4000E0C1FF12200000430000430000', strtoupper(bin2hex(CardProfile::ndefFileSettings(0x20, 0x43))));
    }
}
