<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Enums\CardState;
use App\Enums\MediumStatus;
use App\Enums\RoleSlug;
use App\Enums\VoucherStatus;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\CardEvent;
use App\Models\Medium;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\Support\Ntag424Chip;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * The platform's test restaurant (decision 2026-10-05): its cards go back into stock and are sold again, as often
 * as needed. Real restaurants never get this. The chip is not touched; the old voucher keeps its history.
 */
final class TestCardResetTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->restaurant = $this->restaurant(['name' => 'testni']);
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    /** @return list<Card> cards in the restaurant's stock */
    private function stock(int $count = 2): array
    {
        [$batch, $cards] = $this->shippedCards($this->restaurant, $count);
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/card-batches/{$batch->id}/receipt", ['count' => $count, 'presentment_id' => $this->tapped($this->chip($cards[0]), 'receive')])->assertOk();

        return array_map(static fn (Card $c): Card => $c->refresh(), $cards);
    }

    private function tapped(Ntag424Chip $chip, string $purpose): string
    {
        return (string) $this->tapCard($chip, $purpose)->assertCreated()->json('data.id');
    }

    private function sellCard(Ntag424Chip $chip, int $value = 5000): TestResponse
    {
        return $this->postJson('/api/v1/vouchers', [
            'value' => $value, 'form' => 'card', 'presentment_id' => $this->tapped($chip, 'bind'), 'payment' => ['method' => 'cash'],
        ], $this->idempotency());
    }

    private function markAsTest(bool $test = true): void
    {
        $this->restaurant->forceFill(['is_test' => $test])->save();
    }

    public function test_a_sold_test_card_goes_back_into_stock_and_is_sold_again(): void
    {
        $this->markAsTest();
        [$card] = $this->stock();
        $chip = $this->chip($card);
        $first = (string) $this->sellCard($chip)->assertCreated()->json('data.id');

        $this->getJson('/api/v1/auth/me')->assertOk()->assertJsonPath('data.restaurant.is_test', true);
        $this->postJson("/api/v1/cards/{$card->card_number}/test-reset")->assertOk()->assertJsonPath('data.state', 'available');

        // The old voucher keeps its money history but can no longer be spent; its card link is revoked.
        $old = Voucher::query()->findOrFail($first);
        $this->assertSame(VoucherStatus::Blocked, $old->status);
        $this->assertSame(5000, $old->balance);
        $this->assertSame(MediumStatus::Revoked, Medium::query()->where('voucher_id', $first)->sole()->status);
        $this->assertLedgerConsistent($old);

        // Sold again: a new voucher, and the card pays for that one only.
        $second = (string) $this->sellCard($chip, 2000)->assertCreated()->assertJsonPath('card.state', 'active')->json('data.id');
        $this->assertNotSame($first, $second);
        $this->postJson("/api/v1/vouchers/{$second}/redemptions", ['amount' => 500, 'presentment_id' => $this->tapped($chip, 'spend')], $this->idempotency())
            ->assertCreated()->assertJsonPath('data.voucher.balance', 1500);
        $this->assertSame(1, Medium::query()->where('card_id', $card->id)->where('status', MediumStatus::Active->value)->count());

        // And again: the reset works as often as needed; the card history shows every round.
        $this->postJson("/api/v1/cards/{$card->card_number}/test-reset")->assertOk();
        $this->sellCard($chip, 1000)->assertCreated();
        $this->assertSame(2, CardEvent::query()->withoutGlobalScopes()->where('card_id', $card->id)->where('reason', 'test card back in stock')->count());
        $this->assertDatabaseHas('audit_logs', ['action' => 'card.test_reset']);
    }

    public function test_replaced_lost_and_retired_test_cards_come_back_too(): void
    {
        $this->markAsTest();
        [$card, $other] = $this->stock();
        $this->postJson("/api/v1/cards/{$other->card_number}/revoke", ['reason' => 'test'])->assertOk();
        $this->postJson("/api/v1/cards/{$other->card_number}/test-reset")->assertOk()->assertJsonPath('data.state', 'available');

        $this->sellCard($this->chip($card))->assertCreated();
        $this->postJson("/api/v1/cards/{$card->card_number}/suspend", ['reason' => 'test'])->assertOk();
        $this->postJson("/api/v1/cards/{$card->card_number}/test-reset")->assertOk()->assertJsonPath('data.state', 'available');
    }

    public function test_a_real_restaurant_never_resets_a_card(): void
    {
        [$card] = $this->stock();
        $this->sellCard($this->chip($card))->assertCreated();

        $this->postJson("/api/v1/cards/{$card->card_number}/test-reset")->assertStatus(409)->assertJsonPath('context.reason', 'not_test_restaurant');
        $this->assertSame(CardState::Active, $card->refresh()->state);
        $this->assertSame(VoucherStatus::Active, Voucher::query()->sole()->status);
    }

    public function test_a_card_already_in_stock_is_left_alone_and_waiters_cannot_reset(): void
    {
        $this->markAsTest();
        [$card] = $this->stock();
        $this->postJson("/api/v1/cards/{$card->card_number}/test-reset")->assertStatus(409);

        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->postJson("/api/v1/cards/{$card->card_number}/test-reset")->assertForbidden();
    }

    public function test_only_the_platform_marks_a_test_restaurant(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->putJson('/api/v1/settings/restaurant', ['is_test' => true]);
        $this->assertFalse($this->restaurant->refresh()->is_test);

        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);
        $this->patchJson("/api/v1/admin/restaurants/{$this->restaurant->id}", ['is_test' => true])->assertOk()->assertJsonPath('data.is_test', true);
        $this->assertTrue($this->restaurant->refresh()->is_test);
        $this->assertDatabaseHas('audit_logs', ['action' => 'restaurant.updated', 'restaurant_id' => $this->restaurant->id]);
    }

    /** Audit K9: never a card whose keys leaked. */
    public function test_a_card_with_compromised_keys_never_comes_back(): void
    {
        $this->markAsTest();
        $cards = $this->stock(1);
        $this->sellCard($this->chip($cards[0]))->assertCreated();
        CardBatch::query()->withoutGlobalScopes()->whereKey($cards[0]->batch_id)->update(['status' => 'compromised']);

        $this->postJson("/api/v1/cards/{$cards[0]->card_number}/test-reset")->assertStatus(409)->assertJsonPath('context.reason', 'not_reusable');
    }
}
