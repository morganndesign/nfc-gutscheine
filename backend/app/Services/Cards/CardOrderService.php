<?php

declare(strict_types=1);

namespace App\Services\Cards;

use App\Enums\CardOrderStatus;
use App\Enums\KeySetStatus;
use App\Exceptions\Domain\CardOrderException;
use App\Exceptions\Domain\CardStateException;
use App\Jobs\NotifyCardOrder;
use App\Models\CardOrder;
use App\Models\KeySet;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Restaurants order cards from the platform (app or dashboard). The platform accepts an order, which orders a batch
 * for the restaurant (then the usual station → release → ship → receipt), or declines it with a reason.
 */
final class CardOrderService
{
    /** Open orders a restaurant may have at once: enough for a correction, not a flood of mails. */
    public const MAX_OPEN = 3;

    public const MAX_QUANTITY = 1000;

    public function __construct(
        private readonly CardBatchLifecycle $batches,
        private readonly AuditLogger $audit,
        private readonly CardOrderUpdates $updates,
    ) {}

    /**
     * Places an order for the actor's restaurant (the tenant). With an idempotency key, a repeated request (a lost
     * answer, a double tap) is answered with the order it repeats, never a second one (audit K5).
     */
    public function request(Actor $actor, int $quantity, ?string $note, ?string $idempotencyKey = null): CardOrder
    {
        $note = $note !== null && trim($note) !== '' ? trim($note) : null;
        $created = false;

        $order = DB::transaction(function () use ($actor, $quantity, $note, $idempotencyKey, &$created): CardOrder {
            // Counted under the restaurant's row lock, so two taps cannot both pass the limit.
            $restaurantId = (string) $actor->user?->restaurant_id;
            DB::table('restaurants')->where('id', $restaurantId)->lockForUpdate()->first();
            if ($idempotencyKey !== null) {
                /** @var CardOrder|null $existing */
                $existing = CardOrder::query()->where('idempotency_key', $idempotencyKey)->first();
                if ($existing !== null) {
                    return $existing;
                }
            }
            $created = true;
            if (CardOrder::query()->where('status', CardOrderStatus::Requested)->count() >= self::MAX_OPEN) {
                throw new CardOrderException('', ['reason' => 'too_many_open', 'max_open' => self::MAX_OPEN]);
            }

            $order = new CardOrder(['quantity' => $quantity, 'note' => $note]);
            $order->forceFill([
                'requested_by' => $actor->userId(),
                'status' => CardOrderStatus::Requested,
                'idempotency_key' => $idempotencyKey,
            ])->save();
            $this->audit->log('card.order_requested', $actor, $order, null, ['quantity' => $quantity, 'note' => $note]);

            return $order;
        });

        if ($created) {
            NotifyCardOrder::dispatch($order->getKey())->afterCommit();
        }

        return $order;
    }

    /** Orders the batch for [order]. Platform staff. */
    public function accept(Actor $actor, CardOrder $order, ?string $manufacturer, ?int $quantity): CardOrder
    {
        return DB::transaction(function () use ($actor, $order, $manufacturer, $quantity): CardOrder {
            $locked = $this->lockOpen($order);
            $keySet = KeySet::query()->where('status', KeySetStatus::Active->value)->latest()->first()
                ?? throw new CardStateException('There is no active key set.');
            $batch = $this->batches->order(
                $locked->restaurant,
                $keySet,
                $manufacturer !== null && trim($manufacturer) !== '' ? trim($manufacturer) : 'in-house',
                $quantity ?? $locked->quantity,
                $actor,
            );

            $locked->forceFill([
                'status' => CardOrderStatus::Accepted,
                'card_batch_id' => $batch->getKey(),
                'decided_by' => $actor->userId(),
                'decided_at' => Carbon::now(),
            ])->save();
            $this->audit->log('card.order_accepted', $actor, $locked, ['status' => CardOrderStatus::Requested->value], [
                'status' => CardOrderStatus::Accepted->value,
                'batch_code' => $batch->batch_code,
                'quantity' => $batch->quantity_ordered,
            ]);
            $this->updates->notify($locked->restaurant_id, 'accepted', $batch->quantity_ordered, $locked->requested_by, $batch->batch_code);

            return $locked;
        });
    }

    /** Declines [order] with a reason the restaurant reads. Platform staff. */
    public function decline(Actor $actor, CardOrder $order, string $reason): CardOrder
    {
        return DB::transaction(function () use ($actor, $order, $reason): CardOrder {
            $locked = $this->lockOpen($order);
            $locked->forceFill([
                'status' => CardOrderStatus::Declined,
                'decline_reason' => trim($reason),
                'decided_by' => $actor->userId(),
                'decided_at' => Carbon::now(),
            ])->save();
            $this->audit->log('card.order_declined', $actor, $locked, ['status' => CardOrderStatus::Requested->value], [
                'status' => CardOrderStatus::Declined->value,
                'reason' => trim($reason),
            ]);
            $this->updates->notify($locked->restaurant_id, 'declined', $locked->quantity, $locked->requested_by, reason: trim($reason));

            return $locked;
        });
    }

    private function lockOpen(CardOrder $order): CardOrder
    {
        /** @var CardOrder $locked */
        $locked = CardOrder::query()->withoutGlobalScopes()->whereKey($order->getKey())->lockForUpdate()->firstOrFail();
        if ($locked->status !== CardOrderStatus::Requested) {
            throw new CardOrderException('', ['reason' => 'already_decided', 'status' => $locked->status->value]);
        }

        return $locked;
    }
}
