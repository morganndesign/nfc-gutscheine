<?php

declare(strict_types=1);

namespace App\Services\GiftCards;

use App\Models\AuditLog;
use App\Models\GiftCard;
use App\Models\GiftCardTransaction;

/**
 * Merges the money ledger and the audit trail of a card into one chronological timeline.
 */
final class CardHistoryService
{
    /**
     * @return list<array<string, mixed>>
     */
    public function timeline(GiftCard $card, int $limit = 200): array
    {
        $transactions = GiftCardTransaction::query()
            ->with(['user:id,name', 'device:id,name'])
            ->where('gift_card_id', $card->getKey())
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(static fn (GiftCardTransaction $tx): array => [
                'id' => $tx->getKey(),
                'kind' => 'transaction',
                'type' => $tx->type->value,
                'label' => $tx->type->label(),
                'amount' => $tx->amount,
                'balance_after' => $tx->balance_after,
                'reference' => $tx->reference,
                'note' => $tx->note,
                'reversed' => $tx->isReversed(),
                'user' => $tx->user?->name,
                'device' => $tx->device?->name,
                'created_at' => $tx->created_at->format('Y-m-d\TH:i:s.uP'),
            ]);

        $events = AuditLog::query()
            ->with('user:id,name')
            ->where('auditable_type', 'GiftCard')
            ->where('auditable_id', $card->getKey())
            // Money movements are already represented by their ledger entries.
            ->whereNotIn('action', ['gift_card.redeemed', 'gift_card.reloaded', 'gift_card.issued', 'gift_card.balance_transferred'])
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(static fn (AuditLog $log): array => [
                'id' => $log->getKey(),
                'kind' => 'event',
                'type' => $log->action,
                'label' => ucfirst(str_replace('_', ' ', explode('.', $log->action)[1] ?? $log->action)),
                'amount' => null,
                'balance_after' => null,
                'reference' => null,
                'note' => $log->metadata['reason'] ?? null,
                'reversed' => false,
                'user' => $log->user?->name,
                'device' => null,
                'created_at' => $log->created_at->format('Y-m-d\TH:i:s.uP'),
            ]);

        /** @var list<array<string, mixed>> */
        return $transactions->toBase()->concat($events->all())
            ->sortByDesc('created_at')
            ->take($limit)
            ->values()
            ->all();
    }
}
