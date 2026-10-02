<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\User;
use App\Models\VoucherTransaction;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin VoucherTransaction
 */
final class TransactionResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var VoucherTransaction $tx */
        $tx = $this->resource;
        $viewer = $request->user();
        $viewer = $viewer instanceof User ? $viewer : null;

        return [
            'id' => $tx->id,
            'type' => $tx->type->value,
            'type_label' => $tx->type->label(),
            'amount' => $tx->amount,
            'balance_before' => $tx->balance_before,
            'balance_after' => $tx->balance_after,
            'currency' => $tx->currency,
            'reference' => $tx->reference,
            'note' => $tx->note,
            'reversed' => $tx->isReversed(),
            'reversed_at' => $tx->reversal?->created_at->toIso8601String(),
            // For this viewer: a reload they booked themselves is reversed by someone else (four eyes).
            'reversible' => $tx->isReversibleBy($viewer),
            'related_transaction_id' => $tx->related_transaction_id,
            'payment' => $this->whenLoaded('payment', static fn (): ?array => $tx->payment !== null ? PaymentResource::make($tx->payment)->resolve() : null),
            'voucher' => $this->whenLoaded('voucher', static fn (): array => [
                'id' => $tx->voucher->id,
                'kind' => $tx->voucher->kind->value,
                'voucher_number' => $tx->voucher->voucher_number,
                'status' => $tx->voucher->status->value,
            ]),
            'user' => $this->whenLoaded('user', static fn (): ?array => $tx->user !== null ? ['id' => $tx->user->id, 'name' => $tx->user->name] : null),
            'device' => $this->whenLoaded('device', static fn (): ?array => $tx->device !== null ? ['id' => $tx->device->id, 'name' => $tx->device->name] : null),
            'created_at' => $tx->created_at->toIso8601String(),
        ];
    }
}
