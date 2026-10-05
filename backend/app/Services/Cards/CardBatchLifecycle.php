<?php

declare(strict_types=1);

namespace App\Services\Cards;

use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\KeySetStatus;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\CardStateException;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\KeySet;
use App\Models\Restaurant;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Batch lifecycle (architecture §8): one batch = one restaurant order = one shipment. A status change moves the
 * batch's cards in the same transaction ({@see CardBatchStatus::cardMove()}).
 */
final class CardBatchLifecycle
{
    public function __construct(
        private readonly CardLifecycle $cards,
        private readonly SecurityEventRecorder $events,
    ) {}

    /** Every batch is personalised at the in-house station (keys never leave the provider). */
    public function order(Restaurant $restaurant, KeySet $keySet, string $manufacturer, int $quantity, Actor $actor, ?string $designRef = null): CardBatch
    {
        if ($keySet->status !== KeySetStatus::Active) {
            throw new CardStateException('New batches use an active key set.');
        }
        if ($quantity < 1 || $quantity > 100_000) {
            throw new CardStateException('A batch orders between 1 and 100 000 cards.');
        }

        return DB::transaction(function () use ($restaurant, $keySet, $manufacturer, $quantity, $actor, $designRef): CardBatch {
            $year = Carbon::now()->format('Y');
            $last = CardBatch::query()->withoutGlobalScopes()->where('batch_code', 'like', "B-{$year}-%")->lockForUpdate()->max('batch_code');
            $sequence = is_string($last) ? ((int) substr($last, -4)) + 1 : 1;

            $batch = new CardBatch;
            $batch->forceFill([
                'batch_code' => sprintf('B-%s-%04d', $year, $sequence),
                'restaurant_id' => $restaurant->getKey(),
                'key_set_id' => $keySet->getKey(),
                'manufacturer' => $manufacturer,
                'chip_type' => 'ntag424_dna',
                'card_design_ref' => $designRef,
                'quantity_ordered' => $quantity,
                // The station can start at once: there is no separate order step.
                'status' => CardBatchStatus::InProduction,
                'ordered_at' => Carbon::now(),
            ])->save();

            $this->recordStatus($batch, null, CardBatchStatus::InProduction, 0, $actor);

            return $batch;
        });
    }

    /**
     * Release (§8.4): one platform admin takes the station's QA-passed cards into central stock. Cards the station
     * has not finished are dropped from the batch (QA failed), so the order can ship what is ready.
     */
    public function release(CardBatch $batch, Actor $actor): CardBatch
    {
        return DB::transaction(function () use ($batch, $actor): CardBatch {
            $locked = $this->lock($batch);
            $releaser = $actor->userId() ?? throw new CardStateException('A release needs a person.');
            if ($locked->status !== CardBatchStatus::InProduction) {
                throw new CardStateException('Only a batch in production can be released.');
            }
            $ready = Card::query()->withoutGlobalScopes()->where('batch_id', $locked->getKey())->where('state', CardState::QaPassed->value)->exists();
            if (! $ready) {
                throw new CardStateException('No card of this batch is personalised yet.');
            }
            $dropped = $this->cards->moveBatch($locked, CardState::QaFailed, [CardState::Manufactured, CardState::Personalized], 'not finished at release', $actor);
            $moved = $this->cards->moveBatch($locked, CardState::InInventory, [CardState::QaPassed], 'batch released', $actor);
            $now = Carbon::now();
            $locked->forceFill(['accepted_at' => $now, 'accepted_by' => $releaser, 'personalized_at' => $locked->personalized_at ?? $now]);

            return $this->setStatus($locked, CardBatchStatus::Accepted, $actor, $moved + $dropped);
        });
    }

    /** Ships a released batch to its restaurant. The cards pass through `assigned` so their history stays complete. */
    public function ship(CardBatch $batch, Actor $actor, ?string $trackingRef = null): CardBatch
    {
        return DB::transaction(function () use ($batch, $actor, $trackingRef): CardBatch {
            $locked = $this->lock($batch);
            if ($locked->status !== CardBatchStatus::Accepted) {
                throw new CardStateException('Only a released batch can be shipped.');
            }
            $this->cards->moveBatch($locked, CardState::Assigned, [CardState::InInventory], 'assigned for shipping', $actor);
            $moved = $this->cards->moveBatch($locked, CardState::Shipped, [CardState::Assigned], 'shipped', $actor);
            $locked->forceFill(['shipped_at' => Carbon::now(), 'tracking_ref' => $trackingRef ?? $locked->tracking_ref]);
            // The restaurant hears that the cards are on their way (audit K8).
            $requestedBy = DB::table('card_orders')->where('card_batch_id', $locked->getKey())->value('requested_by');
            app(CardOrderUpdates::class)->notify($locked->restaurant_id, 'shipped', $moved, is_string($requestedBy) ? $requestedBy : null, $locked->batch_code);

            return $this->setStatus($locked, CardBatchStatus::Shipped, $actor, $moved);
        });
    }

    /**
     * The special status changes along §8.2 (rejected, lost, compromised, depleted, closed). Release, shipping and
     * receipt have their own steps.
     *
     * @param  array<string, mixed>  $attributes  e.g. tracking_ref, production_date, qa_report
     */
    public function changeStatus(CardBatch $batch, CardBatchStatus $to, string $reason, Actor $actor, array $attributes = []): CardBatch
    {
        if ($to->hasOwnStep()) {
            throw new CardStateException('Release, shipping and receipt have their own steps.');
        }

        return DB::transaction(function () use ($batch, $to, $reason, $actor, $attributes): CardBatch {
            $locked = $this->lock($batch);
            if ($to === CardBatchStatus::Closed) {
                $open = Card::query()->withoutGlobalScopes()->where('batch_id', $locked->getKey())
                    ->whereNotIn('state', [CardState::Lost->value, CardState::Replaced->value, CardState::Revoked->value, CardState::Destroyed->value])
                    ->exists();
                if ($open) {
                    throw new CardStateException('A batch closes only when all its cards are in a terminal state.');
                }
            }
            $locked->forceFill(array_intersect_key($attributes, array_flip(['tracking_ref', 'production_date', 'qa_report', 'card_design_ref', 'manifest_sha256'])));

            return $this->move($locked, $to, $actor, $reason);
        });
    }

    /**
     * The restaurant confirms a delivery (§11.8): the counted quantity and one tapped card of this batch (proven
     * by the caller with a live authentication). The shipped cards arrive (`delivered`); a matching count makes
     * them available, a mismatch puts the batch on hold for the platform to investigate.
     */
    public function receive(CardBatch $batch, int $counted, Card $tapped, Actor $actor): CardBatch
    {
        return DB::transaction(function () use ($batch, $counted, $tapped, $actor): CardBatch {
            $locked = $this->lock($batch);
            if ($locked->status !== CardBatchStatus::Shipped) {
                throw new CardStateException('Only a shipped batch can be received.');
            }
            if ($tapped->batch_id !== $locked->getKey() || ! in_array($tapped->state, [CardState::Shipped, CardState::Delivered], true)) {
                throw new CardStateException('The tapped card is not a shipped card of this batch.');
            }
            $this->cards->moveBatch($locked, CardState::Delivered, [CardState::Shipped], 'delivered', $actor);
            $delivered = Card::query()->withoutGlobalScopes()->where('batch_id', $locked->getKey())->where('state', CardState::Delivered->value)->count();

            $now = Carbon::now();
            $locked->forceFill(['delivered_at' => $now, 'received_at' => $now, 'received_by' => $actor->userId()]);
            if ($counted !== $delivered) {
                $locked->forceFill(['qa_report' => ($locked->qa_report ?? []) + ['receipt' => ['counted' => $counted, 'expected' => $delivered]]]);

                return $this->setStatus($locked, CardBatchStatus::OnHold, $actor, $delivered);
            }

            $moved = $this->cards->moveBatch($locked, CardState::Available, [CardState::Delivered], 'received', $actor);

            return $this->setStatus($locked, CardBatchStatus::InService, $actor, $moved);
        });
    }

    /**
     * Ends a hold: the cards the platform could not find are lost, the others become available (§8.2).
     *
     * @param  list<Card>  $missing
     */
    public function resolveHold(CardBatch $batch, array $missing, Actor $actor): CardBatch
    {
        return DB::transaction(function () use ($batch, $missing, $actor): CardBatch {
            $locked = $this->lock($batch);
            if ($locked->status !== CardBatchStatus::OnHold) {
                throw new CardStateException('Only a batch on hold can be resolved.');
            }
            foreach ($missing as $card) {
                if ($card->batch_id !== $locked->getKey()) {
                    throw new CardStateException('A missing card belongs to another batch.');
                }
                $this->cards->transition($card, CardState::Lost, 'missing at receipt', $actor, $locked);
            }
            $moved = $this->cards->moveBatch($locked, CardState::Available, [CardState::Delivered], 'received after hold', $actor);

            return $this->setStatus($locked, CardBatchStatus::InService, $actor, $moved + count($missing));
        });
    }

    private function move(CardBatch $batch, CardBatchStatus $to, Actor $actor, string $reason): CardBatch
    {
        if (! $batch->status->canBecome($to)) {
            throw new CardStateException("A batch cannot go from {$batch->status->value} to {$to->value}.");
        }
        $moved = 0;
        foreach ($to->cardMoves() as [$target, $from]) {
            $moved += $this->cards->moveBatch($batch, $target, $from, $reason, $actor);
        }
        if ($to === CardBatchStatus::Compromised) {
            // Leaked keys make guests' cards clonable too: they stop paying at once; the owner replaces them.
            $moved += $this->cards->moveBatch($batch, CardState::Suspended, [CardState::Active], 'keys compromised: '.$reason, $actor);
        }

        return $this->setStatus($batch, $to, $actor, $moved);
    }

    private function setStatus(CardBatch $batch, CardBatchStatus $to, Actor $actor, int $moved): CardBatch
    {
        if (! $batch->status->canBecome($to)) {
            throw new CardStateException("A batch cannot go from {$batch->status->value} to {$to->value}.");
        }
        $from = $batch->status;
        $batch->forceFill(['status' => $to])->save();
        $this->recordStatus($batch, $from, $to, $moved, $actor);

        return $batch;
    }

    private function recordStatus(CardBatch $batch, ?CardBatchStatus $from, CardBatchStatus $to, int $moved, Actor $actor): void
    {
        $this->events->record(SecurityEventType::CardBatchStatus, $actor, data: array_filter([
            'batch_code' => $batch->batch_code,
            'from_status' => $from,
            'to_status' => $to,
            'cards_moved' => $moved,
        ], static fn (mixed $v): bool => $v !== null), restaurantId: $batch->restaurant_id);
    }

    private function lock(CardBatch $batch): CardBatch
    {
        /** @var CardBatch */
        return CardBatch::query()->withoutGlobalScopes()->whereKey($batch->getKey())->lockForUpdate()->firstOrFail();
    }
}
