<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\RoleSlug;
use App\Models\Card;
use App\Models\Restaurant;
use App\Models\Voucher;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\Support\Ntag424Chip;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * Penetration tests against the physical card at the till: an attacker who can read cards on the air, write any
 * chip, replay and edit tap URLs and script the API. Every attack must fail without moving money, and a genuine
 * tap must still work afterwards.
 */
final class CardAttackTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    private Card $card;

    private Voucher $voucher;

    private Ntag424Chip $chip;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->restaurant = $this->restaurant();
        [$this->card, $this->voucher] = $this->activeCardVoucher($this->restaurant, 5000);
        $this->chip = $this->chip($this->card);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        config(['giftcard.security.presentment_failure_limit' => 100]);
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    /** Step 1 of a till tap with any URL and radio UID; the genuine chip answers the challenge. */
    private function begin(string $url, ?string $rfUid = null): TestResponse
    {
        return $this->postJson('/api/v1/presentments/cards', [
            'purpose' => 'spend',
            'tap_url' => $url,
            'rf_uid' => $rfUid ?? $this->chip->uidHex(),
            'challenge' => bin2hex(substr($this->chip->authenticateFirst(), 0, 16)),
        ]);
    }

    private function counter(): int
    {
        return (int) $this->card->refresh()->sdm_counter;
    }

    /** After every attack: nothing was debited and the real card still pays. */
    private function assertUntouchedAndStillWorking(): void
    {
        $this->assertSame(5000, $this->voucher->refresh()->balance);
        $this->tapCard($this->chip)->assertCreated();
    }

    public function test_a_replayed_url_is_refused(): void
    {
        $url = $this->chip->readNdefUrl();
        $this->begin($url)->assertOk();
        $this->begin($url)->assertForbidden()->assertJsonPath('code', 'SUN_REPLAYED');
        $this->assertUntouchedAndStillWorking();
    }

    public function test_a_reused_or_older_counter_is_refused_even_with_fresh_encryption(): void
    {
        $this->tapCard($this->chip)->assertCreated();
        $now = $this->counter();

        // A valid MAC for the same counter (another random padding in the encrypted part) and for an older one.
        $this->begin($this->sunUrl($this->card, $now))->assertForbidden()->assertJsonPath('code', 'SUN_REPLAYED');
        $this->begin($this->sunUrl($this->card, $now - 1))->assertForbidden()->assertJsonPath('code', 'SUN_REPLAYED');
        $this->begin($this->sunUrl($this->card, 0))->assertForbidden()->assertJsonPath('code', 'SUN_REPLAYED');
        $this->assertSame($now, $this->counter(), 'a refused tap never moves the counter');
        $this->assertUntouchedAndStillWorking();
    }

    public function test_an_edited_url_is_refused(): void
    {
        $url = $this->chip->readNdefUrl();
        parse_str((string) parse_url($url, PHP_URL_QUERY), $query);
        $e = (string) $query['e'];
        $m = (string) $query['m'];
        $base = strtok($url, '?');
        $flip = static fn (string $hex, int $at): string => substr_replace($hex, dechex(hexdec($hex[$at]) ^ 1), $at, 1);

        foreach ([
            "{$base}?e={$flip($e, 0)}&m={$m}",           // encrypted UID/counter changed
            "{$base}?e={$flip($e, 31)}&m={$m}",          // last byte of the encrypted part
            "{$base}?e={$e}&m={$flip($m, 0)}",           // CMAC changed
            "{$base}?e={$e}&m={$flip($m, 15)}",
            "{$base}?e={$e}&m=0000000000000000",         // CMAC zeroed
            "{$base}?e=".str_repeat('0', 32)."&m={$m}",   // encrypted part zeroed
        ] as $edited) {
            $this->begin($edited)->assertForbidden()->assertJsonPath('code', 'SUN_VERIFICATION_FAILED');
        }
        $this->assertUntouchedAndStillWorking();
    }

    public function test_forged_identifiers_are_refused(): void
    {
        [$other] = $this->activeCardVoucher($this->restaurant, 9000);
        $next = $this->counter() + 5;

        // Another card's UID inside a correctly encrypted part (K1 is per key set), MACed with this card's key …
        $this->begin($this->sunUrl($this->card, $next, encryptedUid: $other->uid), $other->uidHex())->assertForbidden();
        // … or this card's UID with another card's MAC (K2 is per card).
        $this->begin($this->sunUrl($this->card, $next, macUid: $other->uid))->assertForbidden()->assertJsonPath('code', 'SUN_VERIFICATION_FAILED');
        // A UID that no card has.
        $this->begin($this->sunUrl($this->card, $next, encryptedUid: "\x04".random_bytes(6)))->assertForbidden();
        $this->assertSame(9000, Voucher::query()->whereHas('media', fn ($q) => $q->where('card_id', $other->id))->sole()->balance);
        $this->assertUntouchedAndStillWorking();
    }

    public function test_a_cloned_url_on_another_chip_is_refused(): void
    {
        // A fresh, never used URL read from the real card, presented by a chip with another UID.
        $this->begin($this->chip->readNdefUrl(), '04AABBCCDDEEFF')->assertForbidden()->assertJsonPath('code', 'CARD_AUTHENTICATION_FAILED');
        // The same UID but no K3: the answer to the challenge cannot be produced.
        $begun = $this->begin($this->chip->readNdefUrl())->assertOk();
        $this->postJson('/api/v1/presentments/cards/'.$begun->json('data.authentication'), ['response' => bin2hex(random_bytes(32)).'9100'])
            ->assertForbidden()->assertJsonPath('code', 'CARD_AUTHENTICATION_FAILED');
        $this->assertUntouchedAndStillWorking();
    }

    public function test_a_url_of_another_key_set_origin_or_shape_is_refused(): void
    {
        $url = $this->chip->readNdefUrl();
        foreach ([
            str_replace('/ks-2026-01?', '/ks-2099-01?', $url),
            str_replace((string) config('giftcard.tap_url'), 'https://evil.example/t', $url),
            str_replace('/t/', '/t/../t/', $url),
            (string) strtok($url, '?'),
            $url.'&e=00',
            str_replace('?e=', '?x=', $url),
            'javascript:alert(1)',
            str_repeat('A', 2000),
        ] as $bad) {
            $status = $this->begin($bad)->status();
            $this->assertContains($status, [403, 422], "{$bad} → {$status}");
        }
        $this->assertUntouchedAndStillWorking();
    }

    public function test_malformed_payloads_never_reach_the_crypto(): void
    {
        foreach ([
            ['purpose' => 'spend'],
            ['purpose' => 'refund', 'tap_url' => 'x', 'rf_uid' => '04AABBCCDDEEFF', 'challenge' => str_repeat('0', 32)],
            ['purpose' => 'spend', 'tap_url' => ['array'], 'rf_uid' => '04AABBCCDDEEFF', 'challenge' => str_repeat('0', 32)],
            ['purpose' => 'spend', 'tap_url' => 'x', 'rf_uid' => '04AABBCCDDEE', 'challenge' => str_repeat('0', 32)],
            ['purpose' => 'spend', 'tap_url' => 'x', 'rf_uid' => 'ZZAABBCCDDEEFF', 'challenge' => str_repeat('0', 32)],
            ['purpose' => 'spend', 'tap_url' => 'x', 'rf_uid' => '04AABBCCDDEEFF', 'challenge' => str_repeat('0', 31)],
        ] as $body) {
            $this->postJson('/api/v1/presentments/cards', $body)->assertStatus(422);
        }
        foreach (['not-hex', str_repeat('0', 4000), '00'] as $response) {
            $status = $this->postJson('/api/v1/presentments/cards/'.str_repeat('a', 26), ['response' => $response])->status();
            $this->assertContains($status, [403, 404, 422]);
        }
        $this->assertUntouchedAndStillWorking();
    }

    public function test_an_expired_or_reused_ticket_does_not_pay(): void
    {
        $presentment = (string) $this->tapCard($this->chip)->assertCreated()->json('data.id');
        $redeem = fn (string $id): TestResponse => $this->postJson("/api/v1/vouchers/{$this->voucher->id}/redemptions", ['amount' => 100, 'presentment_id' => $id], $this->idempotency());

        Carbon::setTestNow(Carbon::now()->addSeconds(61));
        $redeem($presentment)->assertStatus(422)->assertJsonPath('context.reason', 'expired');
        Carbon::setTestNow();

        $fresh = (string) $this->tapCard($this->chip)->assertCreated()->json('data.id');
        $redeem($fresh)->assertCreated();
        $redeem($fresh)->assertStatus(422)->assertJsonPath('context.reason', 'already_used');
        $this->assertSame(4900, $this->voucher->refresh()->balance);
    }

    public function test_a_ticket_for_one_purpose_or_voucher_does_not_serve_another(): void
    {
        [, $otherVoucher] = $this->activeCardVoucher($this->restaurant, 3000);
        $presentment = (string) $this->tapCard($this->chip)->assertCreated()->json('data.id');

        $this->postJson("/api/v1/vouchers/{$otherVoucher->id}/redemptions", ['amount' => 100, 'presentment_id' => $presentment], $this->idempotency())
            ->assertStatus(422)->assertJsonPath('context.reason', 'wrong_voucher');
        // A spend ticket cannot sell a card or confirm a delivery.
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $mine = (string) $this->tapCard($this->chip)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/vouchers', ['value' => 1000, 'form' => 'card', 'presentment_id' => $mine, 'payment' => ['method' => 'cash']], $this->idempotency())
            ->assertStatus(422)->assertJsonPath('code', 'PRESENTMENT_INVALID');
        $this->assertSame(3000, $otherVoucher->refresh()->balance);
        $this->assertSame(5000, $this->voucher->refresh()->balance);
    }

    public function test_guessing_is_throttled_per_user_and_device(): void
    {
        config(['giftcard.security.presentment_failure_limit' => 5]);
        for ($i = 0; $i < 5; $i++) {
            $this->begin($this->sunUrl($this->card, 0))->assertForbidden();
        }
        $this->begin($this->chip->readNdefUrl())->assertStatus(429)->assertJsonPath('code', 'PRESENTMENT_THROTTLED');

        // A colleague on another device is not locked out by the attacker.
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->tapCard($this->chip)->assertCreated();
    }

    public function test_a_card_of_a_retired_key_set_or_a_suspended_card_never_pays(): void
    {
        $presentment = (string) $this->tapCard($this->chip)->assertCreated()->json('data.id');
        $this->artisan('cards:key-set:compromised', ['version' => 'ks-2026-01', '--confirm' => 'ks-2026-01'])->assertSuccessful();

        // The ticket issued a moment before the compromise no longer pays, and no new tap is accepted.
        $this->postJson("/api/v1/vouchers/{$this->voucher->id}/redemptions", ['amount' => 100, 'presentment_id' => $presentment], $this->idempotency())
            ->assertStatus(422)->assertJsonPath('context.reason', 'card_not_active');
        $this->tapCard($this->chip)->assertForbidden();
        $this->get((string) parse_url($this->chip->readNdefUrl(), PHP_URL_PATH).'?'.parse_url($this->chip->readNdefUrl(), PHP_URL_QUERY))->assertForbidden();
        $this->assertSame(5000, $this->voucher->refresh()->balance);
    }
}
