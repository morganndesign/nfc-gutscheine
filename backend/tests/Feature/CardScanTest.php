<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\NfcTagType;
use App\Enums\RoleSlug;
use App\Models\GiftCard;
use App\Services\Nfc\Ntag424SunVerifier;
use Illuminate\Support\Str;
use Tests\TestCase;

final class CardScanTest extends TestCase
{
    public function test_waiter_scans_nfc_url_and_sees_minimal_card_view(): void
    {
        $restaurant = $this->restaurant(['name' => 'Trattoria Test']);
        $card = $this->issueCard($restaurant, 4200);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => 'https://app.giftcardpro.test/c/'.$card->public_token])
            ->assertOk()
            ->assertJsonPath('data.id', $card->id)
            ->assertJsonPath('data.restaurant_name', 'Trattoria Test')
            ->assertJsonPath('data.balance', 4200)
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.actions.redeem', true)
            ->assertJsonPath('data.actions.reload', false)
            ->assertJsonPath('data.actions.block', false)
            ->assertJsonMissingPath('data.customer')
            ->assertJsonMissingPath('data.public_token');

        $this->assertDatabaseHas('nfc_scans', ['gift_card_id' => $card->id, 'result' => 'ok', 'method' => 'nfc']);
    }

    public function test_manual_card_number_lookup(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $formatted = trim(chunk_split($card->card_number, 4, ' '));
        $this->postJson('/api/v1/scan', ['method' => 'manual', 'card_number' => $formatted])
            ->assertOk()->assertJsonPath('data.id', $card->id);
    }

    public function test_failed_lookups_are_throttled(): void
    {
        config(['giftcard.security.scan_failure_limit' => 3]);
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        foreach (range(1, 3) as $i) {
            $this->postJson('/api/v1/scan', ['method' => 'qr', 'token' => (string) Str::uuid()])->assertNotFound();
        }

        $this->postJson('/api/v1/scan', ['method' => 'qr', 'token' => (string) Str::uuid()])
            ->assertStatus(429)->assertJsonPath('code', 'SCAN_THROTTLED');
    }

    public function test_cloned_ntag21x_is_detected_by_uid_binding(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->programTag($card, '04:a2:3f:1b:6c:80:12')
            ->assertOk()->assertJsonPath('data.nfc.uid', '04A23F1B6C8012');

        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token, 'nfc_uid' => '04:A2:3F:1B:6C:80:12'])->assertOk();

        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token, 'nfc_uid' => '04:99:99:99:99:99:99'])
            ->assertForbidden()->assertJsonPath('code', 'NFC_UID_MISMATCH');

        $this->assertDatabaseHas('nfc_scans', ['gift_card_id' => $card->id, 'result' => 'uid_mismatch']);
        $this->assertDatabaseHas('audit_logs', ['auditable_id' => $card->id, 'action' => 'gift_card.nfc_uid_mismatch']);
    }

    public function test_one_tag_cannot_be_bound_to_two_active_cards(): void
    {
        $restaurant = $this->restaurant();
        $a = $this->issueCard($restaurant);
        $b = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->programTag($a, '04A23F1B6C8012', 'ntag213')->assertOk();
        $this->postJson("/api/v1/cards/{$b->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => '04A23F1B6C8012'])
            ->assertOk()->assertJsonPath('data.status', 'refused')->assertJsonPath('data.reason', 'TAG_LINKED_TO_OTHER_CARD');
    }

    public function test_ntag424_sun_messages_are_verified_and_replays_rejected(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000, null, ['tag_type' => NfcTagType::Ntag424Dna]);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $uid = '04A39493CC8680';

        $url = 'https://app.giftcardpro.test/c/'.$card->public_token;

        [$picc, $cmac] = $this->sun($uid, 5);
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url."?picc={$picc}&cmac={$cmac}"])->assertOk();

        // Same URL again (copied / sniffed) → replay.
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url."?picc={$picc}&cmac={$cmac}"])
            ->assertForbidden()->assertJsonPath('code', 'NFC_REPLAY_DETECTED');

        // Next genuine tap.
        [$picc, $cmac] = $this->sun($uid, 6);
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url, 'picc' => $picc, 'cmac' => $cmac])->assertOk();

        // Forged MAC.
        [$picc] = $this->sun($uid, 7);
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url, 'picc' => $picc, 'cmac' => '0000000000000000'])
            ->assertForbidden()->assertJsonPath('code', 'NFC_SIGNATURE_INVALID');

        // Different chip carrying a copy of the URL.
        [$picc, $cmac] = $this->sun('04111111111111', 50);
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url, 'picc' => $picc, 'cmac' => $cmac])
            ->assertForbidden()->assertJsonPath('code', 'NFC_UID_MISMATCH');

        // Static URL without SUN data is not accepted for secure tags.
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url])->assertForbidden();

        $this->assertSame(6, GiftCard::query()->withoutGlobalScopes()->findOrFail($card->id)->nfc_read_counter);
    }

    public function test_opened_links_of_secure_chips_are_verified_like_taps(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000, null, ['tag_type' => NfcTagType::Ntag424Dna]);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $url = 'https://app.giftcardpro.test/c/'.$card->public_token;

        // iPhone background reading opens the SUN URL → method "link": verified, and not replayable.
        [$picc, $cmac] = $this->sun('04A39493CC8680', 9);
        $this->postJson('/api/v1/scan', ['method' => 'link', 'token' => $url."?picc={$picc}&cmac={$cmac}"])->assertOk();
        $this->postJson('/api/v1/scan', ['method' => 'link', 'token' => $url."?picc={$picc}&cmac={$cmac}"])
            ->assertForbidden()->assertJsonPath('code', 'NFC_REPLAY_DETECTED');

        // A plain copied link of a secure card is refused; the printed QR code and the number still work.
        $this->postJson('/api/v1/scan', ['method' => 'link', 'token' => $url])->assertForbidden()->assertJsonPath('code', 'NFC_SIGNATURE_INVALID');
        $this->postJson('/api/v1/scan', ['method' => 'qr', 'token' => $url])->assertOk();
    }

    public function test_tap_without_chip_serial_is_refused_for_a_bound_card(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->programTag($card, '04A23F1B6C8012')->assertOk();
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token])
            ->assertForbidden()->assertJsonPath('code', 'NFC_UID_MISMATCH');
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token, 'nfc_uid' => '04A23F1B6C8012'])->assertOk();

        // Binding can be switched off per restaurant (documented setting).
        $restaurant->settings->forceFill(['enforce_nfc_uid_binding' => false])->save();
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token])->assertOk();
    }

    public function test_public_balance_check(): void
    {
        $restaurant = $this->restaurant(['name' => 'Café Public']);
        $card = $this->issueCard($restaurant, 3300);

        $this->getJson("/api/v1/public/cards/{$card->public_token}")
            ->assertOk()
            ->assertJsonPath('data.restaurant_name', 'Café Public')
            ->assertJsonPath('data.balance', 3300)
            ->assertJsonPath('data.card_number', '•••• '.substr($card->card_number, -4))
            ->assertJsonMissingPath('data.id');

        $this->getJson('/api/v1/public/cards/'.Str::uuid())->assertNotFound();

        $restaurant->settings->forceFill(['public_balance_check' => false])->save();
        $this->getJson("/api/v1/public/cards/{$card->public_token}")->assertOk()->assertJsonPath('data.balance_visible', false)->assertJsonMissingPath('data.balance');
    }

    /**
     * Simulates what an NTAG 424 DNA chip mirrors into its URL on a tap.
     *
     * @return array{0: string, 1: string}
     */
    private function sun(string $uidHex, int $counter): array
    {
        $uid = (string) hex2bin($uidHex);
        $ctr = chr($counter & 0xFF).chr(($counter >> 8) & 0xFF).chr(($counter >> 16) & 0xFF);
        $plain = "\xC7".$uid.$ctr.random_bytes(5);

        $enc = openssl_encrypt($plain, 'aes-128-cbc', (string) hex2bin((string) config('giftcard.nfc.ntag424.meta_read_key')), OPENSSL_RAW_DATA | OPENSSL_ZERO_PADDING, str_repeat("\0", 16));
        $mac = app(Ntag424SunVerifier::class)->computeMac($uid, $ctr);

        $this->assertIsString($enc);

        return [strtoupper(bin2hex($enc)), $mac];
    }
}
