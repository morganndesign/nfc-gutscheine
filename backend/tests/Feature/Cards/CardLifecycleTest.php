<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\KeySetStatus;
use App\Enums\RoleSlug;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\CardStateException;
use App\Exceptions\Domain\ImmutableRecordException;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\CardEvent;
use App\Models\KeySet;
use App\Models\Restaurant;
use App\Models\SecurityEvent;
use App\Models\User;
use App\Services\Cards\CardBatchLifecycle;
use App\Services\Cards\CardLifecycle;
use App\Services\Integrity\ChainVerifier;
use App\Support\Actor;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use LogicException;
use Symfony\Component\Finder\Finder;
use Tests\TestCase;

/** Phase 2: physical card model, card lifecycle and batches (architecture §7, §8). */
final class CardLifecycleTest extends TestCase
{
    private Restaurant $restaurant;

    private User $admin;

    private User $secondAdmin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->restaurant = $this->restaurant();
        $this->admin = User::factory()->platformAdmin()->create();
        $this->secondAdmin = User::factory()->platformAdmin()->create();
    }

    private function batches(): CardBatchLifecycle
    {
        return app(CardBatchLifecycle::class);
    }

    private function cards(): CardLifecycle
    {
        return app(CardLifecycle::class);
    }

    private function actor(?User $user = null): Actor
    {
        return new Actor($user ?? $this->admin);
    }

    private function keySet(): KeySet
    {
        return KeySet::query()->firstOrCreate(['version' => 'ks-2026-01'], [
            'manufacturer' => 'Card Co',
            'status' => KeySetStatus::Active,
            'key_check_values' => ['k1' => 'ABCDEF'],
        ]);
    }

    /** @return array{CardBatch, list<Card>} a batch in production with `$quantity` cards, personalised and QA-passed */
    private function personalisedBatch(int $quantity = 3, ?int $ordered = null): array
    {
        $batch = $this->batches()->order($this->restaurant, $this->keySet(), 'Card Co', $ordered ?? $quantity, $this->actor());
        $cards = [];
        for ($i = 0; $i < $quantity; $i++) {
            $cards[] = $this->passedCard($batch);
        }

        return [$batch, $cards];
    }

    private function passedCard(CardBatch $batch): Card
    {
        $card = $this->cards()->register($batch, "\x04".random_bytes(6), $this->actor());
        $card = $this->cards()->transition($card, CardState::Personalized, 'station verified', $this->actor());

        return $this->cards()->transition($card, CardState::QaPassed, 'outsider test passed', $this->actor());
    }

    /** @return array{CardBatch, list<Card>} */
    private function shippedBatch(int $quantity = 3): array
    {
        [$batch, $cards] = $this->personalisedBatch($quantity);
        $this->batches()->release($batch, $this->actor());
        $batch = $this->batches()->ship($batch, $this->actor(), 'AT123');

        return [$batch, array_map(static fn (Card $c): Card => $c->refresh(), $cards)];
    }

    public function test_a_leaked_key_set_rejects_batches_in_production_and_compromises_released_ones(): void
    {
        [$printing, $passed] = $this->personalisedBatch(2);
        $unfinished = $this->cards()->transition($this->cards()->register(
            $this->batches()->order($this->restaurant, $printing->keySet, 'Card Co', 1, $this->actor()), "\x04".random_bytes(6), $this->actor(),
        ), CardState::Personalized, 'station verified', $this->actor());
        [$released, $stock] = $this->personalisedBatch(1);
        $this->batches()->release($released, $this->actor());

        $this->artisan('cards:key-set:compromised', ['version' => 'ks-2026-01', '--confirm' => 'ks-2026-01'])->assertSuccessful();

        $this->assertSame(CardBatchStatus::Rejected, $printing->refresh()->status);
        $this->assertSame(CardState::QaFailed, $unfinished->refresh()->state);
        foreach ($passed as $card) {
            $this->assertSame(CardState::QaFailed, $card->refresh()->state, 'a QA-passed card of a leaked set never reaches stock');
        }
        $this->assertSame(CardBatchStatus::Compromised, $released->refresh()->status);
        $this->assertSame(CardState::Revoked, $stock[0]->refresh()->state);
        $this->expectException(CardStateException::class);
        $this->batches()->release($printing->refresh(), $this->actor());
    }

    public function test_an_order_starts_in_production(): void
    {
        $batch = $this->batches()->order($this->restaurant, $this->keySet(), 'Card Co', 2, $this->actor());

        $this->assertSame(CardBatchStatus::InProduction, $batch->status);
        $event = SecurityEvent::query()->where('type', SecurityEventType::CardBatchStatus->value)->sole();
        $this->assertSame('in_production', $event->data['to_status']);
        $this->assertArrayNotHasKey('from_status', $event->data);
    }

    public function test_one_person_releases_a_batch_and_unfinished_cards_are_dropped(): void
    {
        [$batch, $passed] = $this->personalisedBatch(2, 3);
        $halfway = $this->cards()->transition($this->cards()->register($batch, "\x04".random_bytes(6), $this->actor()), CardState::Personalized, 'station verified', $this->actor());

        $released = $this->batches()->release($batch, $this->actor());

        $this->assertSame(CardBatchStatus::Accepted, $released->status);
        $this->assertSame($this->admin->id, $released->accepted_by);
        $this->assertNotNull($released->accepted_at);
        $this->assertNotNull($released->personalized_at);
        $this->assertSame(CardState::InInventory, $passed[0]->refresh()->state);
        $this->assertSame(CardState::QaFailed, $halfway->refresh()->state);
        $this->assertSame('not finished at release', CardEvent::query()->withoutGlobalScopes()->where('card_id', $halfway->id)->orderByDesc('chain_seq')->value('reason'));

        // Released once: a second release (by anyone) is refused.
        $this->expectException(CardStateException::class);
        $this->batches()->release($released, $this->actor($this->secondAdmin));
    }

    public function test_a_release_needs_a_personalised_card(): void
    {
        $batch = $this->batches()->order($this->restaurant, $this->keySet(), 'Card Co', 2, $this->actor());
        $this->cards()->register($batch, "\x04".random_bytes(6), $this->actor());

        try {
            $this->batches()->release($batch, $this->actor());
            $this->fail('A batch without a QA-passed card was released.');
        } catch (CardStateException) {
            $this->assertSame(CardBatchStatus::InProduction, $batch->refresh()->status);
        }
    }

    public function test_only_a_released_batch_ships(): void
    {
        [$batch, $cards] = $this->personalisedBatch(1);
        try {
            $this->batches()->ship($batch, $this->actor());
            $this->fail('A batch in production was shipped.');
        } catch (CardStateException) {
            $this->addToAssertionCount(1);
        }

        $this->batches()->release($batch, $this->actor());
        $shipped = $this->batches()->ship($batch, $this->actor(), 'AT123');
        $this->assertSame(CardBatchStatus::Shipped, $shipped->status);
        $this->assertSame('AT123', $shipped->tracking_ref);
        $this->assertNotNull($shipped->shipped_at);
        $this->assertSame(CardState::Shipped, $cards[0]->refresh()->state);

        $this->expectException(CardStateException::class);
        $this->batches()->ship($shipped, $this->actor());
    }

    public function test_release_shipping_and_receipt_are_not_set_by_hand(): void
    {
        [$batch] = $this->personalisedBatch(1);
        foreach ([CardBatchStatus::Accepted, CardBatchStatus::Shipped, CardBatchStatus::InService, CardBatchStatus::OnHold] as $status) {
            try {
                $this->batches()->changeStatus($batch, $status, 'by hand', $this->actor());
                $this->fail("{$status->value} was set by hand.");
            } catch (CardStateException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    public function test_a_released_batch_can_still_be_rejected(): void
    {
        [$batch, $cards] = $this->personalisedBatch(1);
        $this->batches()->release($batch, $this->actor());

        $this->assertSame(CardBatchStatus::Rejected, $this->batches()->changeStatus($batch, CardBatchStatus::Rejected, 'wrong artwork', $this->actor())->status);
        $this->assertSame(CardState::Revoked, $cards[0]->refresh()->state);
    }

    public function test_a_batch_travels_from_order_to_the_restaurant_stock(): void
    {
        [$batch, $cards] = $this->personalisedBatch();
        $this->assertMatchesRegularExpression('/^B-\d{4}-0001$/', $batch->batch_code);
        $this->assertSame($batch->batch_code.'-0001', $cards[0]->card_number);
        $this->assertSame(3, $batch->counts()['central_stock']);

        $this->batches()->release($batch, $this->actor());
        $this->assertSame(CardState::InInventory, $cards[0]->refresh()->state);
        $batch = $this->batches()->ship($batch, $this->actor());
        $this->assertSame(3, $batch->counts()['in_transit']);

        $manager = $this->staff($this->restaurant, RoleSlug::Manager);
        $received = $this->batches()->receive($batch, 3, $cards[1]->refresh(), $this->actor($manager));
        $this->assertSame(CardBatchStatus::InService, $received->status);
        $this->assertSame(['available' => 3, 'registered' => 3], array_intersect_key($received->counts(), ['available' => 0, 'registered' => 0]));
        $this->assertSame($manager->id, $received->received_by);
        $this->assertNotNull($received->delivered_at);

        $history = CardEvent::query()->withoutGlobalScopes()->where('card_id', $cards[0]->id)->orderBy('chain_seq')->pluck('to_state')->map(static fn (CardState $s): string => $s->value)->all();
        $this->assertSame(['manufactured', 'personalized', 'qa_passed', 'in_inventory', 'assigned', 'shipped', 'delivered', 'available'], $history);
        $statuses = SecurityEvent::query()->where('type', SecurityEventType::CardBatchStatus->value)->orderBy('id')->get()->map(static fn (SecurityEvent $e): string => (string) $e->data['to_status'])->all();
        $this->assertSame(['in_production', 'accepted', 'shipped', 'in_service'], $statuses);
        $this->assertSame([], app(ChainVerifier::class)->verify());
        $this->assertGreaterThan(0, SecurityEvent::query()->where('type', SecurityEventType::CardTransition->value)->count());
    }

    public function test_a_receipt_needs_a_shipped_batch(): void
    {
        [$batch, $cards] = $this->personalisedBatch(1);
        $this->batches()->release($batch, $this->actor());

        $this->expectException(CardStateException::class);
        $this->batches()->receive($batch, 1, $cards[0]->refresh(), $this->actor());
    }

    public function test_a_count_mismatch_puts_the_batch_on_hold_and_missing_cards_are_lost_for_good(): void
    {
        [$batch, $cards] = $this->shippedBatch();
        $held = $this->batches()->receive($batch, 2, $cards[0], $this->actor());
        $this->assertSame(CardBatchStatus::OnHold, $held->status);
        $this->assertSame(CardState::Delivered, $cards[0]->refresh()->state);

        $resolved = $this->batches()->resolveHold($held, [$cards[2]], $this->actor());
        $this->assertSame(CardBatchStatus::InService, $resolved->status);
        $this->assertSame(CardState::Lost, $cards[2]->refresh()->state);
        $this->assertSame(2, $resolved->counts()['available']);

        $this->expectException(CardStateException::class);
        $this->cards()->transition($cards[2], CardState::Available, 'found', $this->actor());
    }

    public function test_a_compromised_batch_revokes_stock_and_suspends_guests_cards(): void
    {
        [$batch, $cards] = $this->shippedBatch();
        $batch = $this->batches()->receive($batch, 3, $cards[0], $this->actor());
        $this->cards()->transition($cards[0]->refresh(), CardState::Bound, 'sold', $this->actor());
        $this->cards()->transition($cards[0]->refresh(), CardState::Active, 'voucher activated', $this->actor());

        $this->batches()->changeStatus($batch, CardBatchStatus::Compromised, 'key leak', $this->actor());

        // Leaked keys make a guest's card clonable: it stops paying; the balance stays with the voucher for a replacement.
        $this->assertSame(CardState::Suspended, $cards[0]->refresh()->state);
        $this->assertSame(CardState::Revoked, $cards[1]->refresh()->state);
        $this->assertSame(CardState::Revoked, $cards[2]->refresh()->state);
    }

    public function test_only_the_lifecycle_writes_a_card_state_and_only_listed_states_exist(): void
    {
        [, $cards] = $this->personalisedBatch(1);
        $card = $cards[0];

        try {
            $card->forceFill(['state' => CardState::Available])->save();
            $this->fail('A card state was written outside the lifecycle.');
        } catch (LogicException) {
            $this->addToAssertionCount(1);
        }

        try {
            DB::table('cards')->where('id', $card->id)->update(['state' => 'redeemed']);
            $this->fail('The database accepted an unknown card state.');
        } catch (QueryException) {
            $this->addToAssertionCount(1);
        }

        try {
            $this->cards()->transition($card, CardState::Active, 'skip the line', $this->actor());
            $this->fail('A card skipped its lifecycle.');
        } catch (CardStateException) {
            $this->addToAssertionCount(1);
        }

        $event = CardEvent::query()->withoutGlobalScopes()->where('card_id', $card->id)->firstOrFail();
        $this->expectException(ImmutableRecordException::class);
        $event->forceFill(['reason' => 'rewritten'])->save();
    }

    public function test_a_state_written_behind_the_lifecycle_is_detected(): void
    {
        [, $cards] = $this->personalisedBatch(1);
        // Valid state, but not the result of an event.
        DB::table('cards')->where('id', $cards[0]->id)->update(['state' => 'available']);

        $this->assertNotEmpty(array_filter(app(ChainVerifier::class)->verify(), static fn (string $p): bool => str_contains($p, 'not the result of its last card event')));
    }

    public function test_registration_refuses_duplicates_surplus_and_closed_batches(): void
    {
        $batch = $this->batches()->order($this->restaurant, $this->keySet(), 'Card Co', 1, $this->actor());
        $uid = "\x04\x11\x22\x33\x44\x55\x66";
        $this->cards()->register($batch, $uid, $this->actor());

        foreach ([
            fn () => $this->cards()->register($batch, "\x04\x99\x22\x33\x44\x55\x66", $this->actor()), // surplus
            fn () => $this->cards()->register($batch, "\x04\x11", $this->actor()),                     // not a UID
            fn () => $this->cards()->register($batch, $uid, $this->actor()),                             // duplicate
        ] as $attempt) {
            try {
                $attempt();
                $this->fail('A registration was accepted.');
            } catch (CardStateException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    public function test_card_ids_and_uids_never_reach_a_client(): void
    {
        [, $cards] = $this->personalisedBatch(1);
        $serialised = json_encode($cards[0]->toArray(), JSON_THROW_ON_ERROR);
        $this->assertStringNotContainsString($cards[0]->id, $serialised);
        $this->assertArrayNotHasKey('uid', $cards[0]->toArray());
        $this->assertArrayNotHasKey('id', $cards[0]->toArray());

        // No API resource serialises a card id or UID.
        $offenders = [];
        foreach ((new Finder)->files()->in([app_path('Http/Resources')])->name('*.php') as $file) {
            if (preg_match('/->uid\b|[\'"]uid[\'"]|card->id\b|card_id/', $file->getContents()) === 1) {
                $offenders[] = $file->getRelativePathname();
            }
        }
        $this->assertSame([], $offenders);
    }
}
