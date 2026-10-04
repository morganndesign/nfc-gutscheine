<?php

declare(strict_types=1);

namespace App\Services\Media;

use App\Enums\MediumRole;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\SecurityEventType;
use App\Models\Card;
use App\Models\Medium;
use App\Models\Voucher;
use App\Services\Audit\AuditLogger;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Illuminate\Support\Carbon;

/**
 * The link between a card voucher and its physical card (architecture §6.1): one active `nfc_card` medium per
 * card (only a stock card is bound). A card is never reused, except a card of the platform's test restaurant put
 * back into stock (CardService::resetTestCard), which gets a new medium for its next sale. Must run inside the
 * transaction that holds the voucher's and the card's row locks.
 */
final class CardMediumService
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly SecurityEventRecorder $events,
    ) {}

    public function attach(Actor $actor, Voucher $voucher, Card $card, string $cause): Medium
    {
        $medium = new Medium;
        $medium->forceFill([
            'restaurant_id' => $voucher->restaurant_id,
            'voucher_id' => $voucher->getKey(),
            'type' => MediumType::NfcCard,
            'role' => MediumRole::Spend,
            'status' => MediumStatus::Active,
            'card_id' => $card->getKey(),
            'created_by' => $actor->userId(),
        ])->save();

        $this->audit->log('medium.issued', $actor, $medium, null, [
            'type' => MediumType::NfcCard,
            'voucher_id' => $voucher->getKey(),
            'card_number' => $card->card_number,
        ], ['reason' => $cause]);
        $this->events->record(SecurityEventType::MediumIssue, $actor, subject: $voucher, data: [
            'medium_type' => MediumType::NfcCard,
            'cause' => $cause,
        ]);

        return $medium;
    }

    /** The active medium of a card, locked, or null when the card is not linked to a voucher. */
    public function activeOf(Card $card): ?Medium
    {
        /** @var Medium|null */
        return Medium::query()->withoutGlobalScopes()
            ->where('card_id', $card->getKey())
            ->where('status', MediumStatus::Active->value)
            ->lockForUpdate()
            ->first();
    }

    public function revoke(Actor $actor, Medium $medium, Voucher $voucher, string $cause): void
    {
        $medium->forceFill([
            'status' => MediumStatus::Revoked,
            'revoked_at' => Carbon::now(),
            'revoked_by' => $actor->userId(),
            'revoke_reason' => mb_substr($cause, 0, 500),
        ])->save();

        $this->audit->log('medium.revoked', $actor, $medium, null, ['type' => MediumType::NfcCard], ['reason' => $cause]);
        $this->events->record(SecurityEventType::MediumRevoke, $actor, subject: $voucher, data: [
            'medium_type' => MediumType::NfcCard,
            'cause' => $cause,
        ]);
    }
}
