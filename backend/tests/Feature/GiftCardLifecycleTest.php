<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\GiftCardStatus;
use App\Enums\RoleSlug;
use App\Events\GiftCardIssued;
use App\Exceptions\Domain\ImmutableRecordException;
use App\Models\GiftCard;
use App\Models\GiftCardTransaction;
use App\Support\CardNumber;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

final class GiftCardLifecycleTest extends TestCase
{
    public function test_manager_creates_a_card_with_ledger_entry_and_nfc_payload(): void
    {
        Event::fake([GiftCardIssued::class]);
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['card_number_prefix' => '42'])->save();
        $manager = $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $response = $this->postJson('/api/v1/cards', [
            'value' => 5000,
            'expires_at' => now()->addYear()->format('Y-m-d'),
            'customer' => ['first_name' => 'Maria', 'last_name' => 'Berger', 'email' => 'maria@example.com'],
            'notes' => 'Birthday',
            'nfc_tag_type' => 'ntag215',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.balance', 5000)
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.customer.email', 'maria@example.com')
            ->assertJsonPath('transaction.type', 'issue')
            ->assertJsonPath('nfc.tag_type_hint', 'ntag215');

        /** @var GiftCard $card */
        $card = GiftCard::query()->withoutGlobalScopes()->findOrFail($response->json('data.id'));
        $this->assertStringStartsWith('42', $card->card_number);
        $this->assertSame(16, strlen($card->card_number));
        $this->assertTrue(CardNumber::isValid($card->card_number));
        $this->assertMatchesRegularExpression('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/', $card->public_token);
        $this->assertSame($manager->id, $card->issued_by);
        $this->assertSame('https://app.giftcardpro.test/c/'.$card->public_token, $response->json('nfc.url'));
        $this->assertLedgerConsistent($card);
        Event::assertDispatched(GiftCardIssued::class);
    }

    public function test_card_value_limits_are_enforced(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson('/api/v1/cards', ['value' => 100])->assertStatus(422)->assertJsonPath('code', 'INVALID_AMOUNT');
        $this->postJson('/api/v1/cards', ['value' => 100001])->assertStatus(422)->assertJsonPath('code', 'INVALID_AMOUNT');
        $this->postJson('/api/v1/cards', ['value' => 'abc'])->assertStatus(422)->assertJsonValidationErrors('value');
        $this->postJson('/api/v1/cards', ['value' => 5000, 'expires_at' => '2000-01-01'])->assertJsonValidationErrors('expires_at');
    }

    public function test_default_expiration_uses_restaurant_setting(): void
    {
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['default_validity_months' => 12])->save();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $id = $this->postJson('/api/v1/cards', ['value' => 5000])->assertCreated()->json('data.id');

        $card = GiftCard::query()->withoutGlobalScopes()->findOrFail($id);
        $this->assertTrue($card->expires_at->between(now()->addMonths(12)->subDay(), now()->addMonths(12)->addDay()));
    }

    public function test_partial_and_full_redemption(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 1850, 'reference' => 'Table 7'], $this->idempotency())
            ->assertCreated()
            ->assertJsonPath('data.card.balance', 3150)
            ->assertJsonPath('data.card.status', 'active')
            ->assertJsonPath('data.transaction.amount', -1850)
            ->assertJsonPath('data.transaction.balance_after', 3150)
            ->assertJsonPath('data.transaction.reference', 'Table 7');

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 3151], $this->idempotency())
            ->assertStatus(422)
            ->assertJsonPath('code', 'INSUFFICIENT_BALANCE')
            ->assertJsonPath('context.balance', 3150);

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 3150], $this->idempotency())
            ->assertCreated()
            ->assertJsonPath('data.card.balance', 0)
            ->assertJsonPath('data.card.status', 'redeemed');

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 1], $this->idempotency())
            ->assertStatus(422)->assertJsonPath('code', 'CARD_NOT_REDEEMABLE');

        $this->assertLedgerConsistent($card);
        $this->assertSame(5000, $card->refresh()->total_redeemed);
    }

    public function test_redemption_rejects_invalid_amounts(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 0], $this->idempotency())->assertJsonValidationErrors('amount');
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => -500], $this->idempotency())->assertJsonValidationErrors('amount');
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 12.5], $this->idempotency())->assertJsonValidationErrors('amount');
    }

    public function test_full_redemption_only_setting(): void
    {
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['allow_partial_redemption' => false])->save();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 1000], $this->idempotency())->assertJsonPath('code', 'INVALID_AMOUNT');
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 5000], $this->idempotency())->assertCreated();
    }

    public function test_blocked_and_expired_cards_cannot_be_redeemed(): void
    {
        $restaurant = $this->restaurant();
        $blocked = $this->issueCard($restaurant);
        $expiring = $this->issueCard($restaurant, 5000, null, ['expires_at' => now()->addDay()]);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$blocked->id}/block", ['reason' => 'Reported stolen'])
            ->assertOk()->assertJsonPath('data.status', 'blocked')->assertJsonPath('data.blocked_reason', 'Reported stolen');
        $this->postJson("/api/v1/cards/{$blocked->id}/redeem", ['amount' => 100], $this->idempotency())->assertJsonPath('code', 'CARD_BLOCKED');

        $this->postJson("/api/v1/cards/{$blocked->id}/unblock")->assertOk()->assertJsonPath('data.status', 'active');
        $this->postJson("/api/v1/cards/{$blocked->id}/redeem", ['amount' => 100], $this->idempotency())->assertCreated();

        Carbon::setTestNow(now()->addDays(2));
        $this->postJson("/api/v1/cards/{$expiring->id}/redeem", ['amount' => 100], $this->idempotency())->assertJsonPath('code', 'CARD_EXPIRED');
        Carbon::setTestNow();
    }

    public function test_inactive_cards_must_be_activated_first(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000, null, ['activate' => false]);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->assertSame(GiftCardStatus::Inactive, $card->status);
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 100], $this->idempotency())->assertJsonPath('code', 'CARD_NOT_REDEEMABLE');
        $this->postJson("/api/v1/cards/{$card->id}/activate")->assertOk()->assertJsonPath('data.status', 'active');
        $this->postJson("/api/v1/cards/{$card->id}/activate")->assertStatus(409)->assertJsonPath('code', 'INVALID_CARD_STATE');
    }

    public function test_reload_revives_redeemed_cards_and_respects_limits(): void
    {
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['max_card_balance' => 20000])->save();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 5000], $this->idempotency())->assertJsonPath('data.card.status', 'redeemed');
        $this->postJson("/api/v1/cards/{$card->id}/reload", ['amount' => 2500], $this->idempotency())
            ->assertCreated()
            ->assertJsonPath('data.card.balance', 2500)
            ->assertJsonPath('data.card.status', 'active');
        $this->postJson("/api/v1/cards/{$card->id}/reload", ['amount' => 20000], $this->idempotency())->assertJsonPath('code', 'BALANCE_LIMIT_EXCEEDED');

        $restaurant->settings->forceFill(['allow_reload' => false])->save();
        $this->postJson("/api/v1/cards/{$card->id}/reload", ['amount' => 100], $this->idempotency())->assertJsonPath('code', 'RELOAD_NOT_ALLOWED');

        $this->assertSame(7500, $card->refresh()->total_loaded);
        $this->assertLedgerConsistent($card);
    }

    public function test_redemption_can_be_reversed_once(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $txId = $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 5000], $this->idempotency())->json('data.transaction.id');

        $this->postJson("/api/v1/transactions/{$txId}/reverse", ['reason' => 'Wrong card charged'])
            ->assertCreated()
            ->assertJsonPath('data.type', 'reversal')
            ->assertJsonPath('data.amount', 5000);

        $card->refresh();
        $this->assertSame(5000, $card->balance);
        $this->assertSame(GiftCardStatus::Active, $card->status);
        $this->assertSame(0, $card->total_redeemed);

        $this->postJson("/api/v1/transactions/{$txId}/reverse", ['reason' => 'again'])->assertStatus(409)->assertJsonPath('code', 'TRANSACTION_NOT_REVERSIBLE');
        $this->assertLedgerConsistent($card);
    }

    public function test_balance_transfer_between_cards(): void
    {
        $restaurant = $this->restaurant();
        $source = $this->issueCard($restaurant, 5000);
        $target = $this->issueCard($restaurant, 2000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$source->id}/transfer", ['target_card_number' => $target->card_number, 'amount' => 1500], $this->idempotency())
            ->assertOk()
            ->assertJsonPath('data.source.balance', 3500)
            ->assertJsonPath('data.target.balance', 3500);

        $this->postJson("/api/v1/cards/{$source->id}/transfer", ['target_card_id' => $target->id], $this->idempotency())
            ->assertOk()
            ->assertJsonPath('data.source.balance', 0)
            ->assertJsonPath('data.source.status', 'redeemed')
            ->assertJsonPath('data.target.balance', 7000);

        $this->postJson("/api/v1/cards/{$source->id}/transfer", ['target_card_id' => $source->id], $this->idempotency())->assertStatus(409);

        $this->assertLedgerConsistent($source);
        $this->assertLedgerConsistent($target);
    }

    public function test_lost_card_replacement_moves_balance_to_new_card(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 8000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 3000], $this->idempotency());

        $response = $this->postJson("/api/v1/cards/{$card->id}/replace", ['reason' => 'Customer lost the card'])
            ->assertCreated()
            ->assertJsonPath('data.balance', 5000)
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.replaces.id', $card->id);

        $new = GiftCard::query()->withoutGlobalScopes()->findOrFail($response->json('data.id'));
        $old = $card->refresh();

        $this->assertSame(GiftCardStatus::Replaced, $old->status);
        $this->assertSame(0, $old->balance);
        $this->assertSame($new->id, $old->replaced_by_id);
        $this->assertNotSame($old->public_token, $new->public_token);
        $this->assertNotSame($old->card_number, $new->card_number);

        // The old physical card is dead.
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $old->public_token])
            ->assertOk()->assertJsonPath('data.status', 'replaced')->assertJsonPath('data.actions.redeem', false);

        $this->assertLedgerConsistent($old);
        $this->assertLedgerConsistent($new);
    }

    public function test_manual_expiration_writes_off_balance(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$card->id}/expire", ['reason' => 'Terms'])
            ->assertOk()->assertJsonPath('data.status', 'expired')->assertJsonPath('data.balance', 0);

        $this->assertDatabaseHas('gift_card_transactions', ['gift_card_id' => $card->id, 'type' => 'expiration', 'amount' => -5000]);
        $this->postJson("/api/v1/cards/{$card->id}/expire")->assertStatus(409);
        $this->assertLedgerConsistent($card);
    }

    public function test_scheduled_expiration_command(): void
    {
        $restaurant = $this->restaurant();
        $due = $this->issueCard($restaurant, 5000, null, ['expires_at' => now()->addDay()]);
        $valid = $this->issueCard($restaurant, 5000);

        Carbon::setTestNow(now()->addDays(2));
        $this->artisan('giftcards:expire')->assertSuccessful();
        Carbon::setTestNow();

        $this->assertSame(GiftCardStatus::Expired, $due->refresh()->status);
        $this->assertSame(0, $due->balance);
        $this->assertSame(GiftCardStatus::Active, $valid->refresh()->status);
    }

    public function test_card_history_merges_ledger_and_events(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 1000], $this->idempotency());
        $this->postJson("/api/v1/cards/{$card->id}/block", ['reason' => 'Suspicious']);

        $types = collect($this->getJson("/api/v1/cards/{$card->id}/history")->assertOk()->json('data'))->pluck('type');

        $this->assertContains('issue', $types);
        $this->assertContains('redemption', $types);
        $this->assertContains('gift_card.blocked', $types);
    }

    public function test_ledger_rows_are_immutable(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $tx = GiftCardTransaction::query()->withoutGlobalScopes()->where('gift_card_id', $card->id)->firstOrFail();

        $this->expectException(ImmutableRecordException::class);
        $tx->amount = 999999;
        $tx->save();
    }

    public function test_ledger_rows_cannot_be_deleted(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $tx = GiftCardTransaction::query()->withoutGlobalScopes()->where('gift_card_id', $card->id)->firstOrFail();

        $this->expectException(ImmutableRecordException::class);
        $tx->delete();
    }

    public function test_qr_code_is_rendered_as_svg(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $response = $this->get("/api/v1/cards/{$card->id}/qr")->assertOk()->assertHeader('Content-Type', 'image/svg+xml');
        $this->assertStringContainsString('<svg', (string) $response->getContent());
    }
}
