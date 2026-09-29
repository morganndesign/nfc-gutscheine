<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\MediumStatus;
use App\Enums\RoleSlug;
use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType;
use App\Jobs\SendVoucherNotification;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\Medium;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Models\Restaurant;
use App\Models\SecurityAlert;
use App\Models\SecurityEvent;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Cards\CardBatchLifecycle;
use App\Services\Cards\CardLifecycle;
use App\Services\Notifications\VoucherNotificationService;
use App\Support\Actor;
use Illuminate\Support\Facades\Queue;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Symfony\Component\Mime\Email;
use Tests\Support\Ntag424Chip;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * The physical card end to end over the API, as a restaurant and the platform live it: order, personalise,
 * accept, ship, receive, sell, pay, suspend, replace, take out of stock. Every tap is a simulated NTAG 424 DNA
 * chip answering the server's live authentication.
 */
final class CardWorkflowTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->restaurant = $this->restaurant(['name' => 'Gasthaus Stern']);
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    private function asManager(): User
    {
        return $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
    }

    /** A presentment id for the card, tapped now for `$purpose`. */
    private function tapped(Ntag424Chip $chip, string $purpose): string
    {
        return (string) $this->tapCard($chip, $purpose)->assertCreated()->json('data.id');
    }

    private function sellCard(Ntag424Chip $chip, int $value = 5000, ?string $key = null): TestResponse
    {
        return $this->postJson('/api/v1/vouchers', [
            'value' => $value,
            'form' => 'card',
            'presentment_id' => $this->tapped($chip, 'bind'),
            'payment' => ['method' => 'cash'],
        ], $this->idempotency($key));
    }

    /** @return array{0: CardBatch, 1: list<Card>} three cards in the restaurant's stock */
    private function stock(int $count = 3): array
    {
        [$batch, $cards] = $this->deliveredCards($this->restaurant, $count);
        $this->asManager();
        $this->postJson("/api/v1/card-batches/{$batch->id}/receipt", ['count' => $count, 'presentment_id' => $this->tapped($this->chip($cards[0]), 'receive')])
            ->assertOk()->assertJsonPath('data.status', 'in_service');

        return [$batch->refresh(), array_map(static fn (Card $c): Card => $c->refresh(), $cards)];
    }

    public function test_the_platform_orders_personalises_accepts_and_ships_a_batch(): void
    {
        $first = User::factory()->platformAdmin()->create();
        $second = User::factory()->platformAdmin()->create();
        Sanctum::actingAs($first, ['*']);

        $batch = $this->postJson('/api/v1/admin/card-batches', [
            'restaurant_id' => $this->restaurant->id,
            'manufacturer' => 'Card Co',
            'quantity' => 3,
            'card_design_ref' => 'stern-2026',
        ])->assertCreated()->assertJsonPath('data.status', 'ordered')->assertJsonPath('data.key_set', 'ks-2026-01')->json('data.id');
        $this->postJson("/api/v1/admin/card-batches/{$batch}/status", ['status' => 'in_production', 'reason' => 'print run'])->assertOk();

        // Two chips pass the station; the third is left half done and must not be accepted.
        $model = CardBatch::query()->withoutGlobalScopes()->findOrFail($batch);
        $admin = new Actor($first);
        $this->personalizeAtStation($model, Ntag424Chip::factory(), $admin);
        $this->personalizeAtStation($model, Ntag424Chip::factory(), $admin);
        $this->lifecycleRegister($model, $admin);

        foreach (['personalized', 'qa_testing'] as $status) {
            $this->postJson("/api/v1/admin/card-batches/{$batch}/status", ['status' => $status, 'reason' => 'station done'])->assertOk();
        }
        $this->postJson("/api/v1/admin/card-batches/{$batch}/approval")->assertOk()->assertJsonPath('data.status', 'qa_testing');
        $this->postJson("/api/v1/admin/card-batches/{$batch}/approval")->assertStatus(409)->assertJsonPath('code', 'CARD_STATE_INVALID');
        Sanctum::actingAs($second, ['*']);
        $this->postJson("/api/v1/admin/card-batches/{$batch}/approval")->assertOk()
            ->assertJsonPath('data.status', 'accepted')
            ->assertJsonPath('data.counts.central_stock', 2)
            ->assertJsonPath('data.counts.qa_failed', 1);

        foreach (['assigned', 'shipped', 'delivered'] as $status) {
            $this->postJson("/api/v1/admin/card-batches/{$batch}/status", ['status' => $status, 'reason' => 'logistics', 'tracking_ref' => 'AT-1'])->assertOk();
        }
        $this->getJson("/api/v1/admin/card-batches/{$batch}")->assertOk()
            ->assertJsonPath('data.counts.in_transit', 2)
            ->assertJsonPath('data.tracking_ref', 'AT-1')
            ->assertJsonPath('data.restaurant.name', 'Gasthaus Stern');
        $this->getJson('/api/v1/admin/card-batches?status=delivered')->assertOk()->assertJsonCount(1, 'data');

        // Receipt belongs to the restaurant; the platform cannot skip it.
        $this->postJson("/api/v1/admin/card-batches/{$batch}/status", ['status' => 'in_service', 'reason' => 'skip'])->assertStatus(422);
    }

    private function lifecycleRegister(CardBatch $batch, Actor $actor): void
    {
        app(CardLifecycle::class)->register($batch, "\x04".random_bytes(6), $actor);
    }

    public function test_a_restaurant_confirms_a_delivery_with_a_count_and_one_tapped_card(): void
    {
        [$batch, $cards] = $this->deliveredCards($this->restaurant, 3);
        $this->asManager();

        $this->getJson('/api/v1/card-batches')->assertOk()->assertJsonPath('data.0.status', 'delivered')->assertJsonPath('data.0.counts.in_transit', 3);

        // A presentment for another purpose, or reused, does not confirm anything.
        $bind = $this->tapCard($this->chip($cards[1]), 'bind');
        $bind->assertStatus(422)->assertJsonPath('code', 'CARD_NOT_USABLE');
        $receive = $this->tapped($this->chip($cards[1]), 'receive');
        $this->postJson("/api/v1/card-batches/{$batch->id}/receipt", ['count' => 3, 'presentment_id' => $receive])->assertOk()
            ->assertJsonPath('data.status', 'in_service')->assertJsonPath('data.counts.available', 3);
        $this->postJson("/api/v1/card-batches/{$batch->id}/receipt", ['count' => 3, 'presentment_id' => $receive])->assertStatus(422);

        foreach ($cards as $card) {
            $this->assertSame(CardState::Available, $card->refresh()->state);
        }
    }

    public function test_a_wrong_count_puts_the_batch_on_hold_until_the_platform_resolves_it(): void
    {
        [$batch, $cards] = $this->deliveredCards($this->restaurant, 3);
        $this->asManager();
        $this->postJson("/api/v1/card-batches/{$batch->id}/receipt", ['count' => 2, 'presentment_id' => $this->tapped($this->chip($cards[0]), 'receive')])
            ->assertOk()->assertJsonPath('data.status', 'on_hold');
        $this->assertSame(CardState::Delivered, $cards[0]->refresh()->state);

        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);
        $this->postJson("/api/v1/admin/card-batches/{$batch->id}/hold-resolution", ['missing' => ['B-0000-0000-0000']])->assertStatus(409);
        $this->postJson("/api/v1/admin/card-batches/{$batch->id}/hold-resolution", ['missing' => [$cards[2]->card_number]])->assertOk()
            ->assertJsonPath('data.status', 'in_service')
            ->assertJsonPath('data.counts.available', 2)
            ->assertJsonPath('data.counts.lost', 1);
    }

    public function test_a_card_is_sold_by_tapping_it_and_then_pays_only_as_itself(): void
    {
        [, $cards] = $this->stock();
        $chip = $this->chip($cards[0]);

        $sold = $this->sellCard($chip, 5000, 'sale-card-1')->assertCreated()
            ->assertJsonPath('data.kind', 'card')
            ->assertJsonPath('data.balance', 5000)
            ->assertJsonPath('card.card_number', $cards[0]->card_number)
            ->assertJsonPath('card.state', 'active')
            ->assertJsonPath('printable', null);
        $voucherId = (string) $sold->json('data.id');
        $this->assertSame(CardState::Active, $cards[0]->refresh()->state);

        // A retry of the lost answer is the same sale, with no second card and no second payment.
        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'card', 'presentment_id' => $this->tapped($this->chip($cards[1]), 'bind'), 'payment' => ['method' => 'cash']], $this->idempotency('sale-card-1'))
            ->assertOk()->assertJsonPath('replayed', true)->assertJsonPath('data.id', $voucherId);
        $this->assertSame(CardState::Available, $cards[1]->refresh()->state);

        // The card pays; a QR scan never reaches a card voucher.
        $spend = $this->tapped($chip, 'spend');
        $this->postJson("/api/v1/vouchers/{$voucherId}/redemptions", ['amount' => 1800, 'presentment_id' => $spend], $this->idempotency())
            ->assertCreated()->assertJsonPath('data.voucher.balance', 3200);

        // An active card cannot be sold again.
        $this->tapCard($chip, 'bind')->assertStatus(422)->assertJsonPath('code', 'CARD_NOT_USABLE');
        $this->assertLedgerConsistent(Voucher::query()->findOrFail($voucherId));
    }

    public function test_a_bind_presentment_sells_one_card_once(): void
    {
        [, $cards] = $this->stock();
        $presentment = $this->tapped($this->chip($cards[0]), 'bind');
        $body = static fn (string $p): array => ['value' => 3000, 'form' => 'card', 'presentment_id' => $p, 'payment' => ['method' => 'cash']];

        $this->postJson('/api/v1/vouchers', $body($presentment), $this->idempotency())->assertCreated();
        $this->postJson('/api/v1/vouchers', $body($presentment), $this->idempotency())->assertStatus(422)->assertJsonPath('code', 'PRESENTMENT_INVALID');

        // Another user cannot use someone else's tap; a spend presentment does not sell.
        $other = $this->tapped($this->chip($cards[1]), 'bind');
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->postJson('/api/v1/vouchers', $body($other), $this->idempotency())->assertStatus(422)->assertJsonPath('context.reason', 'other_user');

        $this->assertSame(1, Voucher::query()->count());
        $this->assertSame(2, SecurityEvent::query()->where('type', SecurityEventType::VoucherIssue->value)->where('outcome', SecurityEventOutcome::Refused->value)->count());
    }

    public function test_waiters_cannot_sell_or_manage_cards(): void
    {
        [, $cards] = $this->stock();
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);

        $this->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'card', 'presentment_id' => '01a0f000-0000-7000-8000-000000000000', 'payment' => ['method' => 'cash']], $this->idempotency())->assertForbidden();
        $this->tapCard($this->chip($cards[0]), 'bind')->assertForbidden();
        $this->postJson("/api/v1/cards/{$cards[0]->card_number}/revoke", ['reason' => 'damaged'])->assertForbidden();
        $this->getJson('/api/v1/cards')->assertForbidden();
    }

    public function test_a_lost_card_is_suspended_at_once_and_replaced_with_its_balance(): void
    {
        [, $cards] = $this->stock();
        $old = $this->chip($cards[0]);
        $voucherId = (string) $this->sellCard($old, 5000)->json('data.id');
        $number = $cards[0]->card_number;

        // A tap made before the guest called no longer pays once the card is suspended.
        $early = $this->tapped($old, 'spend');
        $this->postJson("/api/v1/cards/{$number}/suspend", ['reason' => 'guest reported it lost'])->assertOk()->assertJsonPath('data.state', 'suspended');
        $this->postJson("/api/v1/vouchers/{$voucherId}/redemptions", ['amount' => 500, 'presentment_id' => $early], $this->idempotency())
            ->assertStatus(422)->assertJsonPath('context.reason', 'card_not_active');
        $this->tapCard($old, 'spend')->assertStatus(422)->assertJsonPath('code', 'CARD_NOT_USABLE');

        // Replacement: the new stock card takes over the voucher; no money moves.
        $new = $this->chip($cards[1]);
        $this->postJson("/api/v1/cards/{$number}/replacement", ['presentment_id' => $this->tapped($new, 'bind'), 'reason' => 'lost'])->assertOk()
            ->assertJsonPath('data.card_number', $cards[1]->card_number)
            ->assertJsonPath('data.state', 'active')
            ->assertJsonPath('data.voucher.id', $voucherId)
            ->assertJsonPath('data.voucher.balance', 5000);
        $this->getJson("/api/v1/cards/{$number}")->assertOk()
            ->assertJsonPath('data.state', 'replaced')
            ->assertJsonPath('data.successor', $cards[1]->card_number)
            ->assertJsonPath('data.voucher', null);

        $this->postJson("/api/v1/vouchers/{$voucherId}/redemptions", ['amount' => 1000, 'presentment_id' => $this->tapped($new, 'spend')], $this->idempotency())
            ->assertCreated()->assertJsonPath('data.voucher.balance', 4000);
        $this->tapCard($old, 'spend')->assertStatus(422)->assertJsonPath('code', 'CARD_NOT_USABLE');
        $this->assertSame(1, Medium::query()->where('voucher_id', $voucherId)->where('status', MediumStatus::Active->value)->count());

        // Found again: a replaced card never comes back.
        $this->postJson("/api/v1/cards/{$number}/resume", ['reason' => 'found'])->assertStatus(409);
    }

    public function test_the_guest_is_told_of_a_replacement_and_many_replacements_raise_an_alert(): void
    {
        Queue::fake();
        [, $cards] = $this->stock(6);
        $voucherIds = [];
        foreach ([0, 1, 2] as $i) {
            $voucherIds[] = (string) $this->postJson('/api/v1/vouchers', [
                'value' => 3000,
                'form' => 'card',
                'presentment_id' => $this->tapped($this->chip($cards[$i]), 'bind'),
                'payment' => ['method' => 'cash'],
                'customer' => ['email' => "guest{$i}@example.com"],
            ], $this->idempotency())->assertCreated()->json('data.id');
        }
        $manager = $this->asManager();

        foreach ([0, 1, 2] as $i) {
            $this->postJson("/api/v1/cards/{$cards[$i]->card_number}/replacement", ['presentment_id' => $this->tapped($this->chip($cards[$i + 3]), 'bind'), 'reason' => 'damaged'])->assertOk();
        }

        foreach ($voucherIds as $voucherId) {
            Queue::assertPushed(SendVoucherNotification::class, static fn (SendVoucherNotification $job): bool => $job->voucherId === $voucherId && $job->templateKey === NotificationTemplate::KEY_CARD_REPLACED);
        }
        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $alert = SecurityAlert::query()->where('rule', 'card.replacements')->sole();
        $this->assertSame('user:'.$manager->id, $alert->subject);

        // The e-mail itself: when and where, never the card number or the balance.
        config(['mail.default' => 'array']);
        app(VoucherNotificationService::class)->send(Voucher::query()->findOrFail($voucherIds[0]), NotificationTemplate::KEY_CARD_REPLACED);
        $log = NotificationLog::query()->where('template_key', 'card_replaced')->sole();
        $this->assertSame('sent', $log->status);
        $mail = app('mailer')->getSymfonyTransport()->messages()->last()->getOriginalMessage();
        $this->assertInstanceOf(Email::class, $mail);
        $text = (string) $mail->getTextBody();
        $this->assertMatchesRegularExpression('/ersetzt|replaced/', $text);
        $this->assertStringNotContainsString($cards[3]->card_number, $text);
        $this->assertDoesNotMatchRegularExpression('/30,00|30\.00|€/', $text);
    }

    public function test_a_suspended_card_can_be_resumed(): void
    {
        [, $cards] = $this->stock();
        $chip = $this->chip($cards[0]);
        $voucherId = (string) $this->sellCard($chip, 2000)->json('data.id');
        $number = $cards[0]->card_number;

        $this->postJson("/api/v1/cards/{$number}/suspend", ['reason' => 'check'])->assertOk();
        $this->postJson("/api/v1/cards/{$number}/suspend", ['reason' => 'check'])->assertStatus(409);
        $this->postJson("/api/v1/cards/{$number}/resume", ['reason' => 'found in the coat'])->assertOk()->assertJsonPath('data.state', 'active');
        $this->postJson("/api/v1/vouchers/{$voucherId}/redemptions", ['amount' => 2000, 'presentment_id' => $this->tapped($chip, 'spend')], $this->idempotency())->assertCreated();
    }

    public function test_replacement_needs_a_stock_card_of_this_restaurant(): void
    {
        $other = $this->restaurant(['name' => 'Anderswo']);
        [, $foreign] = $this->deliveredCards($other, 1);
        [, $cards] = $this->stock();
        $this->sellCard($this->chip($cards[0]), 2000);
        $this->sellCard($this->chip($cards[1]), 2000);
        $number = $cards[0]->card_number;

        // Another active card cannot be tapped as a replacement.
        $this->tapCard($this->chip($cards[1]), 'bind')->assertStatus(422)->assertJsonPath('code', 'CARD_NOT_USABLE');

        // A card of another restaurant is refused at the tap.
        $this->tapCard($this->chip($foreign[0]), 'bind')->assertStatus(422)->assertJsonPath('context.reason', 'other_restaurant');

        // A stock card that is only available cannot be "replaced".
        $this->postJson("/api/v1/cards/{$cards[2]->card_number}/replacement", ['presentment_id' => $this->tapped($this->chip($cards[2]), 'bind'), 'reason' => 'x x'])->assertStatus(409);
        $this->assertSame(CardState::Available, $cards[2]->refresh()->state, 'the refused replacement consumed nothing');
        $this->assertSame(CardState::Active, $cards[0]->refresh()->state);
        $this->assertSame(1, SecurityEvent::query()->where('type', SecurityEventType::CardTransition->value)->where('outcome', SecurityEventOutcome::Refused->value)->count());
        $this->assertNotNull($number);
    }

    public function test_a_stock_card_is_taken_out_of_service_but_a_guests_card_is_not(): void
    {
        [, $cards] = $this->stock();
        $this->sellCard($this->chip($cards[0]), 2000);

        $this->postJson("/api/v1/cards/{$cards[1]->card_number}/revoke", ['reason' => 'damaged'])->assertOk()->assertJsonPath('data.state', 'revoked');
        $this->postJson("/api/v1/cards/{$cards[0]->card_number}/revoke", ['reason' => 'damaged'])->assertStatus(409);
        $this->tapCard($this->chip($cards[1]), 'bind')->assertStatus(422)->assertJsonPath('code', 'CARD_NOT_USABLE');
    }

    public function test_the_card_list_and_history_never_show_ids_or_uids(): void
    {
        [, $cards] = $this->stock();
        $this->sellCard($this->chip($cards[0]), 2000);

        $list = $this->getJson('/api/v1/cards?state[]=active')->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.card_number', $cards[0]->card_number)
            ->assertJsonPath('data.0.voucher.balance', 2000);
        $show = $this->getJson("/api/v1/cards/{$cards[0]->card_number}")->assertOk()
            ->assertJsonPath('data.history.0.to_state', 'manufactured')
            ->assertJsonPath('data.history.9.to_state', 'active');
        $this->getJson('/api/v1/cards?search='.substr($cards[2]->card_number, -4))->assertOk()->assertJsonPath('data.0.card_number', $cards[2]->card_number);

        foreach ([$list, $show] as $response) {
            $body = strtolower((string) $response->getContent());
            foreach ($cards as $card) {
                $this->assertStringNotContainsString(strtolower($card->uidHex()), $body);
                $this->assertStringNotContainsString($card->id, $body);
            }
        }

        // Another restaurant sees none of it.
        $this->actingAsStaff($this->restaurant(['name' => 'Anderswo']), RoleSlug::Manager);
        $this->getJson("/api/v1/cards/{$cards[0]->card_number}")->assertNotFound();
        $this->getJson('/api/v1/cards')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_receipt_is_bound_to_its_batch(): void
    {
        [$first, $firstCards] = $this->deliveredCards($this->restaurant, 1);
        [$second] = $this->deliveredCards($this->restaurant, 1);
        $this->asManager();

        $this->postJson("/api/v1/card-batches/{$second->id}/receipt", ['count' => 1, 'presentment_id' => $this->tapped($this->chip($firstCards[0]), 'receive')])
            ->assertStatus(422)->assertJsonPath('context.reason', 'other_batch');
        $this->assertSame(CardBatchStatus::Delivered, $second->refresh()->status);
        $this->assertSame(CardBatchStatus::Delivered, $first->refresh()->status, 'the refused receipt consumed nothing');
        $this->assertNotNull(app(CardBatchLifecycle::class));
    }
}
