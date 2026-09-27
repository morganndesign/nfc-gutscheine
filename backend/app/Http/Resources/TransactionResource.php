<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\GiftCardTransaction;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin GiftCardTransaction
 */
final class TransactionResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var GiftCardTransaction $tx */
        $tx = $this->resource;

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
            'reversed_at' => $tx->reversed_at?->toIso8601String(),
            'reversible' => $tx->type->isReversible() && ! $tx->isReversed(),
            'related_transaction_id' => $tx->related_transaction_id,
            'gift_card' => $this->whenLoaded('giftCard', static fn (): array => [
                'id' => $tx->giftCard->id,
                'card_number' => $tx->giftCard->card_number,
                'status' => $tx->giftCard->status->value,
            ]),
            'user' => $this->whenLoaded('user', static fn (): ?array => $tx->user !== null ? ['id' => $tx->user->id, 'name' => $tx->user->name] : null),
            'device' => $this->whenLoaded('device', static fn (): ?array => $tx->device !== null ? ['id' => $tx->device->id, 'name' => $tx->device->name] : null),
            'created_at' => $tx->created_at->toIso8601String(),
        ];
    }
}
