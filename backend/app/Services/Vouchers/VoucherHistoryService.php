<?php

declare(strict_types=1);

namespace App\Services\Vouchers;

use App\Models\AuditLog;
use App\Models\User;
use App\Models\Voucher;
use App\Models\VoucherTransaction;

/**
 * Merges a voucher's ledger and its audit trail into one chronological timeline.
 */
final class VoucherHistoryService
{
    /** Money movements appear as their ledger entries. */
    private const LEDGER_ACTIONS = ['voucher.sold', 'voucher.redeemed', 'voucher.reloaded'];

    /**
     * @return list<array<string, mixed>>
     */
    public function timeline(Voucher $voucher, ?User $viewer = null, int $limit = 200): array
    {
        $transactions = VoucherTransaction::query()
            ->with(['user:id,name', 'device:id,name', 'reversal:id,related_transaction_id', 'payment'])
            ->where('voucher_id', $voucher->getKey())
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->each(static fn (VoucherTransaction $tx) => $tx->setRelation('voucher', $voucher))
            ->map(static fn (VoucherTransaction $tx): array => [
                'id' => $tx->getKey(),
                'kind' => 'transaction',
                'type' => $tx->type->value,
                'label' => $tx->type->label(),
                'amount' => $tx->amount,
                'balance_after' => $tx->balance_after,
                'reference' => $tx->reference,
                'note' => $tx->note,
                'payment_method' => $tx->payment?->method->value,
                'reversed' => $tx->isReversed(),
                // For this viewer (four eyes on one's own reload; nothing on a closed voucher).
                'reversible' => $tx->isReversibleBy($viewer),
                'user' => $tx->user?->name,
                'device' => $tx->device?->name,
                'created_at' => $tx->created_at->format('Y-m-d\TH:i:s.uP'),
            ]);

        $events = AuditLog::query()
            ->with('user:id,name')
            ->where('auditable_type', 'Voucher')
            ->where('auditable_id', $voucher->getKey())
            ->whereNotIn('action', self::LEDGER_ACTIONS)
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
                'payment_method' => null,
                'reversed' => false,
                'reversible' => false,
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
