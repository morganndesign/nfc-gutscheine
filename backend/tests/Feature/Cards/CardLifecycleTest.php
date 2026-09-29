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
        return KeySet::query()->create([
            'version' => 'ks-2026-01',
            'manufacturer' => 'Card Co',
            'status' => KeySetStatus::Active,
            'key_check_values' => ['k1' => 'ABCDEF'],
        ]);
    }

    /** @return array{CardBatch, list<Card>} a batch of `$quantity` cards, personalised and QA-tested */
    private function qaTestedBatch(int $quantity = 3): array
    {
        $batch = $this->batches()->order($this->restaurant, $this->keySet(), 'Card Co', $quantity, $this->actor());
        $batch = $this->batches()->changeStatus($batch, CardBatchStatus::InProduction, 'printing', $this->actor());
        $cards = [];
        for ($i = 0; $i < $quantity; $i++) {
            $card = $this->cards()->register($batch, "\x04".random_bytes(6), $this->actor());
            $card = $this->cards()->transition($card, CardState::Personalized, 'station verified', $this->actor());
            $cards[] = $this->cards()->transition($card, CardState::QaPassed, 'outsider test passed', $this->actor());
        }
        $batch = $this->batches()->changeStatus($batch, CardBatchStatus::Personalized, 'all personalised', $this->actor());
        $batch = $this->batches()->changeStatus($batch, CardBatchStatus::QaTesting, 'sample test', $this->actor());

        return [$batch, $cards];
    }

    /** @return array{CardBatch, list<Card>} */
    private function deliveredBatch(int $quantity = 3): array
    {
        [$batch, $cards] = $this->qaTestedBatch($quantity);
        $batch = $this->batches()->approve($batch, $this->actor());
        $batch = $this->batches()->approve($batch, $this->actor($this->secondAdmin));
        foreach ([CardBatchStatus::Assigned, CardBatchStatus::Shipped, CardBatchStatus::Delivered] as $status) {
            $batch = $this->batches()->changeStatus($batch, $status, $status->value, $this->actor(), ['tracking_ref' => 'AT123']);
        }

        return [$batch, array_map(static fn (Card $c): Card => $c->refresh(), $cards)];
    }

    public function test_a_batch_travels_from_order_to_the_restaurant_stock(): void
    {
        [$batch, $cards] = $this->qaTestedBatch();
        $this->assertMatchesRegularExpression('/^B-\d{4}-0001$/', $batch->batch_code);
        $this->assertSame($batch->batch_code.'-0001', $cards[0]->card_number);
        $this->assertSame(3, $batch->counts()['central_stock']);

        $first = $this->batches()->approve($batch, $this->actor());
        $this->assertSame(CardBatchStatus::QaTesting, $first->status, 'one approval is not enough');
        try {
            $this->batches()->approve($batch, $this->actor());
            $this->fail('The same person approved twice.');
        } catch (CardStateException) {
            $this->addToAssertionCount(1);
        }
        $accepted = $this->batches()->approve($batch, $this->actor($this->secondAdmin));
        $this->assertSame(CardBatchStatus::Accepted, $accepted->status);
        $this->assertSame(CardState::InInventory, $cards[0]->refresh()->state);

        foreach ([CardBatchStatus::Assigned, CardBatchStatus::Shipped, CardBatchStatus::Delivered] as $status) {
            $batch = $this->batches()->changeStatus($accepted, $status, $status->value, $this->actor());
        }
        $this->assertSame(3, $batch->counts()['in_transit']);

        $manager = $this->staff($this->restaurant, RoleSlug::Manager);
        $received = $this->batches()->receive($batch, 3, $cards[1]->refresh(), $this->actor($manager));
        $this->assertSame(CardBatchStatus::InService, $received->status);
        $this->assertSame(['available' => 3, 'registered' => 3], array_intersect_key($received->counts(), ['available' => 0, 'registered' => 0]));
        $this->assertSame($manager->id, $received->received_by);

        $history = CardEvent::query()->withoutGlobalScopes()->where('card_id', $cards[0]->id)->orderBy('chain_seq')->pluck('to_state')->map(static fn (CardState $s): string => $s->value)->all();
        $this->assertSame(['manufactured', 'personalized', 'qa_passed', 'in_inventory', 'assigned', 'shipped', 'delivered', 'available'], $history);
        $this->assertSame([], app(ChainVerifier::class)->verify());
        $this->assertGreaterThan(0, SecurityEvent::query()->where('type', SecurityEventType::CardTransition->value)->count());
    }

    public function test_a_count_mismatch_puts_the_batch_on_hold_and_missing_cards_are_lost_for_good(): void
    {
        [$batch, $cards] = $this->deliveredBatch();
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
        [$batch, $cards] = $this->deliveredBatch();
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
        [, $cards] = $this->qaTestedBatch(1);
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
        [, $cards] = $this->qaTestedBatch(1);
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
        [, $cards] = $this->qaTestedBatch(1);
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
