<?php

declare(strict_types=1);

namespace App\Services\Cards;

use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\CardStateException;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\CardEvent;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Closure;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * The only writer of card state (architecture §7): it checks the transition, writes the new state and appends a
 * hash-chained `card_events` row and a security event, all in one transaction. The Card model refuses a state
 * write from anywhere else.
 */
final class CardLifecycle
{
    private static int $writing = 0;

    public function __construct(private readonly SecurityEventRecorder $events) {}

    public static function isWriting(): bool
    {
        return self::$writing > 0;
    }

    /**
     * Registers a blank chip tapped at the station for its batch (`manufactured`). The inventory number is
     * `<batch code>-<sequence>`.
     */
    public function register(CardBatch $batch, string $uid, Actor $actor, ?string $originalitySignature = null): Card
    {
        $initial = CardState::Manufactured;
        if (strlen($uid) !== 7) {
            throw new CardStateException('An NTAG 424 DNA UID is 7 bytes.');
        }

        return DB::transaction(function () use ($batch, $uid, $initial, $actor, $originalitySignature): Card {
            /** @var CardBatch $locked */
            $locked = CardBatch::query()->withoutGlobalScopes()->whereKey($batch->getKey())->lockForUpdate()->firstOrFail();
            if ($locked->status !== CardBatchStatus::InProduction) {
                throw new CardStateException('Cards are registered only while their batch is in production.');
            }
            $registered = Card::query()->withoutGlobalScopes()->where('batch_id', $locked->getKey())->count();
            // Chips refused at the station (not genuine) keep their number but not their place in the order.
            $usable = Card::query()->withoutGlobalScopes()->where('batch_id', $locked->getKey())->where('state', '!=', CardState::QaFailed->value)->count();
            if ($usable >= $locked->quantity_ordered) {
                throw new CardStateException('The batch already has every card it ordered.');
            }
            if (Card::query()->withoutGlobalScopes()->where('uid', $uid)->exists()) {
                throw new CardStateException('This chip is already registered.');
            }

            $card = new Card;
            $card->forceFill([
                'card_number' => sprintf('%s-%04d', $locked->batch_code, $registered + 1),
                'uid' => $uid,
                'chip_type' => $locked->chip_type,
                'batch_id' => $locked->getKey(),
                'key_set_id' => $locked->key_set_id,
                'restaurant_id' => $locked->restaurant_id,
                'originality_signature' => $originalitySignature,
            ]);

            return $this->writing(function () use ($card, $initial, $actor, $locked): Card {
                $card->forceFill(['state' => $initial, 'state_changed_at' => Carbon::now()])->save();
                $this->record($card, null, $initial, 'registered', $actor, null, $locked->batch_code);

                return $card;
            });
        });
    }

    /** One card, one step along the lifecycle. The card row is locked; a concurrent change waits and is re-checked. */
    /** @param  Card|null  $successor  the card that takes over (replacement) */
    public function transition(Card $card, CardState $to, string $reason, Actor $actor, ?Model $ref = null, ?Card $successor = null): Card
    {
        return DB::transaction(function () use ($card, $to, $reason, $actor, $ref, $successor): Card {
            /** @var Card $locked */
            $locked = Card::query()->withoutGlobalScopes()->whereKey($card->getKey())->lockForUpdate()->firstOrFail();
            $from = $locked->state;
            if (! $from->canBecome($to)) {
                throw new CardStateException("A card cannot go from {$from->value} to {$to->value}.", ['from' => $from->value, 'to' => $to->value]);
            }

            if ($successor !== null && $to !== CardState::Replaced) {
                throw new CardStateException('Only a replaced card has a successor.');
            }

            return $this->writing(function () use ($locked, $from, $to, $reason, $actor, $ref, $successor): Card {
                $locked->forceFill(['state' => $to, 'state_changed_at' => Carbon::now()] + ($successor !== null ? ['successor_card_id' => $successor->getKey()] : []))->save();
                $this->record($locked, $from, $to, $reason, $actor, $ref);

                return $locked;
            });
        });
    }

    /**
     * A card of the platform's test restaurant goes back into its stock (decision 2026-10-05). The one way back in the lifecycle, and only for a test restaurant: real cards are never reused.
     */
    public function backToTestStock(Card $card, Actor $actor): Card
    {
        return DB::transaction(function () use ($card, $actor): Card {
            /** @var Card $locked */
            $locked = Card::query()->withoutGlobalScopes()->whereKey($card->getKey())->lockForUpdate()->firstOrFail();
            $from = $locked->state;
            $isTest = (bool) DB::table('restaurants')->where('id', $locked->restaurant_id)->value('is_test');
            if (! $isTest) {
                throw new CardStateException('Only cards of a test restaurant go back into stock.', ['reason' => 'not_test_restaurant']);
            }
            // Cards the restaurant has had: sold, blocked, replaced, taken out of service or lost. Not stock already,
            // not a destroyed chip, not a card still on its way from the platform.
            if (! in_array($from, [CardState::Bound, CardState::Active, CardState::Suspended, CardState::Replaced, CardState::Revoked, CardState::Lost], true)) {
                throw new CardStateException("A {$from->value} card cannot go back into stock.", ['state' => $from->value]);
            }
            // Never a card whose keys leaked, nor one lost on its way from the platform (audit K9).
            $batchStatus = DB::table('card_batches')->where('id', $locked->batch_id)->value('status');
            if (! CardService::resumable($locked) || ($from === CardState::Lost && in_array($batchStatus, ['shipped', 'lost'], true))) {
                throw new CardStateException('This card cannot go back into stock.', ['reason' => 'not_reusable']);
            }

            return $this->writing(function () use ($locked, $from, $actor): Card {
                $locked->forceFill(['state' => CardState::Available, 'state_changed_at' => Carbon::now(), 'successor_card_id' => null])->save();
                $this->record($locked, $from, CardState::Available, 'test card back in stock', $actor, null);

                return $locked;
            });
        });
    }

    /**
     * A card sold by mistake whose sale was cancelled (unused, the same day; decision 2026-10-06, K1): back into the
     * restaurant's stock, to be sold again. The chip is not touched (selling never writes to it). The only other
     * way back in the lifecycle besides the test restaurant's reset.
     */
    public function backToStockAfterCancel(Card $card, Actor $actor, ?Model $ref = null): Card
    {
        return DB::transaction(function () use ($card, $actor, $ref): Card {
            /** @var Card $locked */
            $locked = Card::query()->withoutGlobalScopes()->whereKey($card->getKey())->lockForUpdate()->firstOrFail();
            $from = $locked->state;
            if ($from !== CardState::Active) {
                throw new CardStateException("A {$from->value} card cannot go back into stock.", ['state' => $from->value]);
            }

            return $this->writing(function () use ($locked, $from, $actor, $ref): Card {
                $locked->forceFill(['state' => CardState::Available, 'state_changed_at' => Carbon::now()])->save();
                $this->record($locked, $from, CardState::Available, 'sale cancelled: back in stock', $actor, $ref);

                return $locked;
            });
        });
    }

    /**
     * Moves every card of a batch that is in one of `$from` to `$to` (a batch status change, §8.2). Runs inside
     * the caller's transaction; returns the number of cards moved.
     *
     * @param  list<CardState>  $from
     */
    public function moveBatch(CardBatch $batch, CardState $to, array $from, string $reason, Actor $actor): int
    {
        $cards = Card::query()->withoutGlobalScopes()
            ->where('batch_id', $batch->getKey())
            ->whereIn('state', array_map(static fn (CardState $s): string => $s->value, $from))
            ->orderBy('card_number')
            ->lockForUpdate()
            ->get();

        return $this->writing(function () use ($cards, $to, $reason, $actor, $batch): int {
            foreach ($cards as $card) {
                /** @var Card $card */
                $previous = $card->state;
                if (! $previous->canBecome($to)) {
                    throw new CardStateException("Card {$card->card_number} cannot go from {$previous->value} to {$to->value}.");
                }
                $card->forceFill(['state' => $to, 'state_changed_at' => Carbon::now()])->save();
                $this->record($card, $previous, $to, $reason, $actor, $batch, $batch->batch_code);
            }

            return $cards->count();
        });
    }

    /**
     * @template T
     *
     * @param  Closure(): T  $write
     * @return T
     */
    private function writing(Closure $write): mixed
    {
        self::$writing++;
        try {
            return $write();
        } finally {
            self::$writing--;
        }
    }

    private function record(Card $card, ?CardState $from, CardState $to, string $reason, Actor $actor, ?Model $ref, ?string $batchCode = null): void
    {
        $event = new CardEvent;
        $event->forceFill([
            'card_id' => $card->getKey(),
            'batch_id' => $card->batch_id,
            'restaurant_id' => $card->restaurant_id,
            'from_state' => $from,
            'to_state' => $to,
            'reason' => mb_substr($reason, 0, 120),
            'actor_id' => $actor->userId(),
            'device_id' => $actor->deviceId(),
            'request_id' => $actor->requestId,
            'ref_type' => $ref !== null ? class_basename($ref) : null,
            'ref_id' => $ref !== null ? (string) $ref->getKey() : null,
        ])->save();

        $this->events->record(SecurityEventType::CardTransition, $actor, data: array_filter([
            'card_number' => $card->card_number,
            'from_state' => $from,
            'to_state' => $to,
            'cause' => $reason,
            'batch_code' => $batchCode,
        ], static fn (mixed $v): bool => $v !== null), restaurantId: $card->restaurant_id);
    }
}
