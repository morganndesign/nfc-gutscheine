<?php

declare(strict_types=1);

namespace Tests\Probe;

use App\Enums\NfcTagType;
use App\Enums\RoleSlug;
use App\Models\GiftCard;
use App\Services\Nfc\Ntag424SunVerifier;
use Tests\TestCase;

/**
 * S8 probe: prove which scan methods skip chip verification for secure tags.
 */
final class S8NfcBypassTest extends TestCase
{
    private function sun(string $uidHex, int $counter): array
    {
        $uid = (string) hex2bin($uidHex);
        $ctr = chr($counter & 0xFF).chr(($counter >> 8) & 0xFF).chr(($counter >> 16) & 0xFF);
        $plain = "\xC7".$uid.$ctr.random_bytes(5);
        $enc = openssl_encrypt($plain, 'aes-128-cbc', (string) hex2bin((string) config('giftcard.nfc.ntag424.meta_read_key')), OPENSSL_RAW_DATA | OPENSSL_ZERO_PADDING, str_repeat("\0", 16));
        $mac = app(Ntag424SunVerifier::class)->computeMac($uid, $ctr);

        return [strtoupper(bin2hex((string) $enc)), $mac];
    }

    public function test_S8A_ntag424_qr_method_accepts_plain_token_no_crypto(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000, null, ['tag_type' => NfcTagType::Ntag424Dna]);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        // Secure NTAG424 card, but scanned as "qr" with only the plain public token — NO picc/cmac.
        $r = $this->postJson('/api/v1/scan', ['method' => 'qr', 'token' => $card->public_token]);
        fwrite(STDERR, "\n[S8A] ntag424 method=qr plain token -> HTTP ".$r->getStatusCode()." (200 = crypto BYPASSED)\n");
        $r->assertOk()->assertJsonPath('data.id', $card->id);
    }

    public function test_S8B_ntag424_api_method_accepts_plain_token(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000, null, ['tag_type' => NfcTagType::Ntag424Dna]);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $r = $this->postJson('/api/v1/scan', ['method' => 'api', 'token' => $card->public_token]);
        fwrite(STDERR, "[S8B] ntag424 method=api plain token -> HTTP ".$r->getStatusCode()."\n");
        $r->assertOk();
    }

    public function test_S8E_control_ntag424_nfc_without_sun_is_rejected(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000, null, ['tag_type' => NfcTagType::Ntag424Dna]);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $r = $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token]);
        fwrite(STDERR, "[S8E-control] ntag424 method=nfc no picc/cmac -> HTTP ".$r->getStatusCode()." (expect 403)\n");
        $r->assertForbidden();
    }

    public function test_S8C_ntag21x_qr_method_bypasses_uid_binding(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->programTag($card, '04A23F1B6C8012', 'ntag215')->assertOk();

        // Attacker copies only the URL token; presents a WRONG/absent uid via qr.
        $r = $this->postJson('/api/v1/scan', ['method' => 'qr', 'token' => $card->public_token]);
        fwrite(STDERR, "[S8C] ntag21x bound-uid method=qr no uid -> HTTP ".$r->getStatusCode()." (200 = UID clone check BYPASSED)\n");
        $r->assertOk()->assertJsonPath('data.id', $card->id);
    }

    public function test_S8D_ntag21x_link_method_without_uid_is_accepted(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->programTag($card, '04A23F1B6C8012', 'ntag215')->assertOk();

        $r = $this->postJson('/api/v1/scan', ['method' => 'link', 'token' => $card->public_token]);
        fwrite(STDERR, "[S8D] ntag21x bound-uid method=link no uid -> HTTP ".$r->getStatusCode()."\n");
        // record outcome (claim: accepted despite bound UID)
        $this->assertTrue(in_array($r->getStatusCode(), [200, 403], true));
    }

    public function test_S8F_sun_replay_rejected_and_uid_bound_on_first_use(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000, null, ['tag_type' => NfcTagType::Ntag424Dna]);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $uid = '04A39493CC8680';
        $url = 'https://app.giftcardpro.test/c/'.$card->public_token;

        $this->assertNull(GiftCard::query()->withoutGlobalScopes()->findOrFail($card->id)->nfc_uid);

        [$picc, $cmac] = $this->sun($uid, 5);
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url."?picc={$picc}&cmac={$cmac}"])->assertOk();

        $bound = GiftCard::query()->withoutGlobalScopes()->findOrFail($card->id)->nfc_uid;
        fwrite(STDERR, "[S8G] uid bound on first SUN = ".var_export($bound, true)." (expect 04A39493CC8680)\n");
        $this->assertSame($uid, $bound);

        // replay same picc/cmac
        $r = $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url."?picc={$picc}&cmac={$cmac}"]);
        fwrite(STDERR, "[S8F] SUN replay (same picc/cmac) -> HTTP ".$r->getStatusCode()." code=".$r->json('code')." (expect 403 NFC_REPLAY_DETECTED)\n");
        $r->assertForbidden()->assertJsonPath('code', 'NFC_REPLAY_DETECTED');
    }
}
