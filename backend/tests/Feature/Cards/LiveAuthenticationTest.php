<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Enums\CardState;
use App\Enums\RoleSlug;
use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType;
use App\Models\Card;
use App\Models\Presentment;
use App\Models\Restaurant;
use App\Models\SecurityEvent;
use App\Services\Cards\CardLifecycle;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\Support\Ntag424Chip;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * Phase 4: a physical card pays only after it answered the server's AES challenge through the phone (A3), end to
 * end over the API with a simulated NTAG 424 DNA chip.
 */
final class LiveAuthenticationTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->restaurant = $this->restaurant(['name' => 'Beisl am Eck']);
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    /** What the phone does: read the NDEF URL, start EV2 with K3, relay the server's command, relay the answer. */
    private function tap(Ntag424Chip $chip, string $purpose = 'spend', ?string $rfUid = null, ?string $url = null): TestResponse
    {
        $url ??= $chip->readNdefUrl();
        $challenge = substr($chip->authenticateFirst(), 0, 16);
        $begun = $this->postJson('/api/v1/presentments/cards', [
            'purpose' => $purpose,
            'tap_url' => $url,
            'rf_uid' => $rfUid ?? $chip->uidHex(),
            'challenge' => bin2hex($challenge),
        ]);
        if ($begun->status() !== 200) {
            return $begun;
        }

        $answer = $chip->transceive((string) hex2bin((string) $begun->json('data.command')));

        return $this->postJson('/api/v1/presentments/cards/'.$begun->json('data.authentication'), ['response' => bin2hex($answer)]);
    }

    public function test_a_card_pays_after_answering_the_challenge_through_the_phone(): void
    {
        [$card, $voucher] = $this->activeCardVoucher($this->restaurant, 5000);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);

        $presented = $this->tap($this->chip($card))->assertCreated()
            ->assertJsonPath('data.method', 'live_auth')
            ->assertJsonPath('data.level', 'A3')
            ->assertJsonPath('data.voucher.id', $voucher->id)
            ->assertJsonPath('data.voucher.balance', 5000)
            ->assertJsonPath('data.card.card_number', $card->card_number);
        $this->assertStringNotContainsString($card->id, (string) $presented->getContent());
        $this->assertStringNotContainsString(strtolower($card->uidHex()), strtolower((string) $presented->getContent()));

        $this->postJson("/api/v1/vouchers/{$voucher->id}/redemptions", ['amount' => 1200, 'presentment_id' => $presented->json('data.id')], $this->idempotency())
            ->assertCreated()
            ->assertJsonPath('data.voucher.balance', 3800);

        $done = SecurityEvent::query()->where('type', SecurityEventType::CardAuthenticate->value)->where('outcome', 'succeeded')->sole();
        $this->assertSame('spend', $done->data['purpose']);
    }

    public function test_a_copied_tap_url_or_a_cloned_ndef_never_passes(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $chip = $this->chip($card);

        $url = $chip->readNdefUrl();
        $this->tap($chip, url: $url)->assertCreated();
        // The same URL again (recorded, copied): the counter did not move.
        $this->tap($chip, url: $url)->assertForbidden()->assertJsonPath('code', 'SUN_REPLAYED');
        // A fresh URL copied onto another chip: the radio layer shows another UID.
        $this->tap($chip, rfUid: '04AAAAAAAAAAAA')->assertForbidden()->assertJsonPath('code', 'CARD_AUTHENTICATION_FAILED');
    }

    public function test_a_chip_without_the_card_keys_cannot_answer_and_a_challenge_is_used_once(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        [, $foreign] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $real = $this->chip($card);
        $impostor = $this->chip(Card::query()->whereHas('batch')->where('id', '!=', $card->id)->firstOrFail());

        // The genuine URL and radio UID, but the challenge is answered by a chip with other keys.
        $begun = $this->postJson('/api/v1/presentments/cards', [
            'purpose' => 'spend',
            'tap_url' => $real->readNdefUrl(),
            'rf_uid' => $real->uidHex(),
            'challenge' => bin2hex(substr($impostor->authenticateFirst(), 0, 16)),
        ])->assertOk();
        $impostor->transceive((string) hex2bin((string) $begun->json('data.command')));
        // Without K3 the impostor can only send something of the right shape.
        $this->postJson('/api/v1/presentments/cards/'.$begun->json('data.authentication'), ['response' => bin2hex(random_bytes(32)).'9100'])
            ->assertForbidden()->assertJsonPath('code', 'CARD_AUTHENTICATION_FAILED');

        // Honest attempt, then the same authentication again.
        $begun = $this->postJson('/api/v1/presentments/cards', [
            'purpose' => 'spend',
            'tap_url' => $real->readNdefUrl(),
            'rf_uid' => $real->uidHex(),
            'challenge' => bin2hex(substr($real->authenticateFirst(), 0, 16)),
        ])->assertOk();
        $answer = bin2hex($real->transceive((string) hex2bin((string) $begun->json('data.command'))));
        $this->postJson('/api/v1/presentments/cards/'.$begun->json('data.authentication'), ['response' => $answer])->assertCreated();
        $this->postJson('/api/v1/presentments/cards/'.$begun->json('data.authentication'), ['response' => $answer])->assertForbidden();
        $this->assertNotNull($foreign);
    }

    public function test_a_challenge_expires_after_30_seconds(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $chip = $this->chip($card);

        $begun = $this->postJson('/api/v1/presentments/cards', [
            'purpose' => 'spend',
            'tap_url' => $chip->readNdefUrl(),
            'rf_uid' => $chip->uidHex(),
            'challenge' => bin2hex(substr($chip->authenticateFirst(), 0, 16)),
        ])->assertOk()->assertJsonPath('data.expires_in', 30);
        $answer = bin2hex($chip->transceive((string) hex2bin((string) $begun->json('data.command'))));

        Carbon::setTestNow(Carbon::now()->addSeconds(31));
        $this->postJson('/api/v1/presentments/cards/'.$begun->json('data.authentication'), ['response' => $answer])->assertForbidden();
    }

    public function test_only_an_active_bound_card_of_this_restaurant_pays(): void
    {
        [$foreign] = $this->activeCardVoucher($this->restaurant(['name' => 'Anderswo']));
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);

        $stock = $this->availableCard($this->restaurant);
        $this->tap($this->chip($stock))->assertUnprocessable()->assertJsonPath('code', 'CARD_NOT_USABLE')->assertJsonPath('context.state', 'available');

        [$suspended] = $this->activeCardVoucher($this->restaurant);
        app(CardLifecycle::class)->transition($suspended, CardState::Suspended, 'guest reported it lost', Actor::system());
        $this->tap($this->chip($suspended->refresh()))->assertUnprocessable()->assertJsonPath('context.state', 'suspended');

        $this->tap($this->chip($foreign))->assertUnprocessable()->assertJsonPath('context.reason', 'other_restaurant');
    }

    public function test_a_card_suspended_after_the_tap_no_longer_pays(): void
    {
        [$card, $voucher] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $presentment = $this->tap($this->chip($card))->assertCreated()->json('data.id');

        app(CardLifecycle::class)->transition($card, CardState::Suspended, 'guest reported it lost', Actor::system());

        $this->postJson("/api/v1/vouchers/{$voucher->id}/redemptions", ['amount' => 100, 'presentment_id' => $presentment], $this->idempotency())
            ->assertUnprocessable()
            ->assertJsonPath('code', 'PRESENTMENT_INVALID')
            ->assertJsonPath('context.reason', 'card_not_active');
    }

    public function test_a_manager_confirms_a_delivery_with_a_tapped_card_and_waiters_cannot(): void
    {
        [, $cards] = $this->deliveredCards($this->restaurant, 2);

        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->postJson('/api/v1/presentments/cards', ['purpose' => 'receive', 'tap_url' => 'x', 'rf_uid' => '04AAAAAAAAAAAA', 'challenge' => str_repeat('0', 32)])
            ->assertForbidden();

        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $this->tap($this->chip($cards[0]), 'receive')->assertCreated()
            ->assertJsonPath('data.purpose', 'receive')
            ->assertJsonPath('data.voucher', null)
            ->assertJsonPath('data.card.state', 'delivered');
    }

    public function test_repeated_failures_lock_out_the_same_user_and_device(): void
    {
        config(['giftcard.security.presentment_failure_limit' => 3]);
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $chip = $this->chip($card);

        for ($i = 0; $i < 3; $i++) {
            $this->tap($chip, rfUid: '04AAAAAAAAAAAA')->assertForbidden();
        }
        $this->tap($chip)->assertStatus(429)->assertJsonPath('code', 'PRESENTMENT_THROTTLED');

        $refusals = SecurityEvent::query()->where('type', SecurityEventType::CardAuthenticate->value)->where('outcome', SecurityEventOutcome::Refused->value)->count();
        $this->assertSame(4, $refusals);
    }

    public function test_a_tap_url_of_another_origin_is_not_accepted(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $chip = $this->chip($card);
        $url = str_replace((string) config('giftcard.tap_url'), 'https://evil.example/t', $chip->readNdefUrl());
        $this->assertStringStartsWith('https://evil.example/t/', $url);

        $this->tap($chip, url: $url)->assertForbidden()->assertJsonPath('code', 'SUN_VERIFICATION_FAILED');
    }

    public function test_the_presentment_records_the_counter_of_its_own_tap(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $chip = $this->chip($card);

        $url = $chip->readNdefUrl();
        $challenge = substr($chip->authenticateFirst(), 0, 16);
        $begun = $this->postJson('/api/v1/presentments/cards', ['purpose' => 'spend', 'tap_url' => $url, 'rf_uid' => $chip->uidHex(), 'challenge' => bin2hex($challenge)])->assertOk();
        $tapped = (int) $card->refresh()->sdm_counter;
        $answer = $chip->transceive((string) hex2bin((string) $begun->json('data.command')));

        // The guest's phone reads the card in between: the card's counter moves on, this tap's does not.
        $this->get(str_replace((string) config('giftcard.tap_url'), '/t', $chip->readNdefUrl()))->assertOk();
        $this->assertSame($tapped + 1, $card->refresh()->sdm_counter);

        $id = $this->postJson('/api/v1/presentments/cards/'.$begun->json('data.authentication'), ['response' => bin2hex($answer)])->assertCreated()->json('data.id');
        $this->assertSame($tapped, Presentment::query()->findOrFail($id)->sdm_counter);
        $this->assertSame($tapped, SecurityEvent::query()->where('type', SecurityEventType::CardAuthenticate->value)->sole()->data['counter']);
    }
}
