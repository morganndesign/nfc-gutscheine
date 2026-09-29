<?php

declare(strict_types=1);

namespace App\Services\Cards;

use App\Enums\CardState;
use App\Enums\PresentmentPurpose;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\CardStateException;
use App\Exceptions\Domain\DomainException;
use App\Exceptions\Domain\PresentmentInvalidException;
use App\Exceptions\Domain\TenantMismatchException;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\Voucher;
use App\Services\Audit\AuditLogger;
use App\Services\Media\CardMediumService;
use App\Services\Presentments\PresentmentService;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Support\Facades\DB;

/**
 * What a restaurant does with its physical cards (architecture §11): confirm a delivery, suspend and resume a
 * guest's card, replace a lost or damaged one (the balance stays with the voucher, the new card takes over), and
 * take a stock card out of service. Every step that needs the physical card consumes a live-authenticated
 * presentment in the same transaction. Lock order: presentment → cards → voucher.
 */
final class CardService
{
    private const DB_ATTEMPTS = 3;

    public function __construct(
        private readonly TenantContext $tenant,
        private readonly CardLifecycle $lifecycle,
        private readonly CardBatchLifecycle $batches,
        private readonly CardMediumService $media,
        private readonly PresentmentService $presentments,
        private readonly AuditLogger $audit,
        private readonly SecurityEventRecorder $events,
    ) {}

    /** Delivery receipt: the counted quantity and one card of the batch tapped by the person confirming. */
    public function receive(Actor $actor, CardBatch $batch, int $counted, string $presentmentId): CardBatch
    {
        $this->assertTenant($batch->restaurant_id);

        return $this->guarded($actor, 'receipt', null, $batch->batch_code, fn (): CardBatch => DB::transaction(function () use ($actor, $batch, $counted, $presentmentId): CardBatch {
            $presentment = $this->presentments->lockForUse($presentmentId);
            $card = $this->presentments->consumeCard($presentment, $actor, PresentmentPurpose::Receive);
            if ($card->batch_id !== $batch->getKey()) {
                throw new PresentmentInvalidException('', ['reason' => 'other_batch']);
            }

            return $this->batches->receive($batch, $counted, $card, $actor);
        }, self::DB_ATTEMPTS));
    }

    /** A guest reports the card lost or stolen, or staff stop it: it no longer pays until resumed or replaced. */
    public function suspend(Actor $actor, Card $card, string $reason): Card
    {
        return $this->change($actor, $card, CardState::Suspended, $reason, [CardState::Active]);
    }

    public function resume(Actor $actor, Card $card, string $reason): Card
    {
        return $this->change($actor, $card, CardState::Active, $reason, [CardState::Suspended]);
    }

    /** A stock card that is damaged, missing or not to be sold: out of service for good. */
    public function revoke(Actor $actor, Card $card, string $reason): Card
    {
        return $this->change($actor, $card, CardState::Revoked, $reason, [CardState::Delivered, CardState::Available]);
    }

    /**
     * Replacement: the old card (active or suspended) is replaced for good and the tapped stock card takes over its
     * voucher. No money moves; the voucher, its balance and its history stay the same.
     */
    public function replace(Actor $actor, Card $old, string $presentmentId, string $reason): Card
    {
        $this->assertTenant($old->restaurant_id);

        return $this->guarded($actor, 'replacement', $old->card_number, null, fn (): Card => DB::transaction(function () use ($actor, $old, $presentmentId, $reason): Card {
            $presentment = $this->presentments->lockForUse($presentmentId);
            $new = $this->presentments->consumeCard($presentment, $actor, PresentmentPurpose::Bind);

            /** @var Card $locked */
            $locked = Card::query()->withoutGlobalScopes()->whereKey($old->getKey())->lockForUpdate()->firstOrFail();
            if ($locked->getKey() === $new->getKey()) {
                throw new CardStateException('A card cannot replace itself.');
            }
            if (! in_array($locked->state, [CardState::Active, CardState::Suspended], true)) {
                throw new CardStateException('Only an active or suspended card can be replaced.', ['state' => $locked->state->value]);
            }
            $medium = $this->media->activeOf($locked) ?? throw new CardStateException('This card is not linked to a voucher.');
            /** @var Voucher $voucher */
            $voucher = Voucher::query()->whereKey($medium->voucher_id)->lockForUpdate()->firstOrFail();

            $this->media->revoke($actor, $medium, $voucher, 'card replaced');
            $this->lifecycle->transition($locked, CardState::Replaced, mb_substr('replaced: '.$reason, 0, 120), $actor, $voucher, successor: $new);
            $this->lifecycle->transition($new, CardState::Bound, 'replacement for '.$locked->card_number, $actor, $voucher);
            $this->media->attach($actor, $voucher, $new, 'replacement');
            $active = $this->lifecycle->transition($new, CardState::Active, 'voucher activated', $actor, $voucher);

            $this->audit->log('card.replaced', $actor, $voucher, null, [
                'old_card' => $locked->card_number,
                'new_card' => $new->card_number,
            ], ['reason' => $reason]);

            return $active;
        }, self::DB_ATTEMPTS));
    }

    /** @param list<CardState> $from */
    private function change(Actor $actor, Card $card, CardState $to, string $reason, array $from): Card
    {
        $this->assertTenant($card->restaurant_id);

        return $this->guarded($actor, $to->value, $card->card_number, null, fn (): Card => DB::transaction(function () use ($actor, $card, $to, $reason, $from): Card {
            /** @var Card $locked */
            $locked = Card::query()->withoutGlobalScopes()->whereKey($card->getKey())->lockForUpdate()->firstOrFail();
            if (! in_array($locked->state, $from, true)) {
                throw new CardStateException("A {$locked->state->value} card cannot become {$to->value} here.", ['state' => $locked->state->value]);
            }

            return $this->lifecycle->transition($locked, $to, $reason, $actor);
        }, self::DB_ATTEMPTS));
    }

    private function assertTenant(string $restaurantId): void
    {
        if ($restaurantId !== $this->tenant->id()) {
            throw new TenantMismatchException;
        }
    }

    /**
     * Runs a card operation; a refusal is recorded in the security stream after the rollback and rethrown.
     *
     * @template T
     *
     * @param  \Closure(): T  $operation
     * @return T
     */
    private function guarded(Actor $actor, string $cause, ?string $cardNumber, ?string $batchCode, \Closure $operation): mixed
    {
        try {
            return $operation();
        } catch (DomainException $refusal) {
            $this->events->refused(SecurityEventType::CardTransition, $actor, $refusal, data: array_filter([
                'card_number' => $cardNumber,
                'batch_code' => $batchCode,
                'cause' => $cause,
            ], static fn (?string $v): bool => $v !== null));

            throw $refusal;
        }
    }
}
