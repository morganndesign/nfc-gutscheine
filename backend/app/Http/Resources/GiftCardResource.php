<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\GiftCard;
use App\Services\GiftCards\CardUrlBuilder;
use App\Support\CardNumber;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Full card representation for back-office users.
 *
 * @mixin GiftCard
 */
final class GiftCardResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var GiftCard $card */
        $card = $this->resource;

        return [
            'id' => $card->id,
            'card_number' => $card->card_number,
            'card_number_formatted' => CardNumber::format($card->card_number),
            'status' => $card->status->value,
            'currency' => $card->currency,
            'initial_value' => $card->initial_value,
            'balance' => $card->balance,
            'total_loaded' => $card->total_loaded,
            'total_redeemed' => $card->total_redeemed,
            'expires_at' => $card->expires_at?->toIso8601String(),
            'is_expired' => $card->isExpiredByDate(),
            'activated_at' => $card->activated_at?->toIso8601String(),
            'redeemed_at' => $card->redeemed_at?->toIso8601String(),
            'blocked_at' => $card->blocked_at?->toIso8601String(),
            'blocked_reason' => $card->blocked_reason,
            'expired_at' => $card->expired_at?->toIso8601String(),
            'recipient_name' => $card->recipient_name,
            'notes' => $card->notes,
            'customer' => CustomerResource::make($this->whenLoaded('customer')),
            'issued_by' => $this->whenLoaded('issuer', static fn () => $card->issuer !== null ? ['id' => $card->issuer->id, 'name' => $card->issuer->name] : null),
            'replaced_by' => $this->whenLoaded('replacedBy', static fn () => $card->replacedBy !== null ? ['id' => $card->replacedBy->id, 'card_number' => $card->replacedBy->card_number] : null),
            'replaces' => $this->whenLoaded('replaces', static fn () => $card->replaces !== null ? ['id' => $card->replaces->id, 'card_number' => $card->replaces->card_number] : null),
            'nfc' => [
                'tag_type' => $card->nfc_tag_type?->value,
                'uid' => $card->nfc_uid,
                'written_at' => $card->nfc_written_at?->toIso8601String(),
                'verified_at' => $card->nfc_verified_at?->toIso8601String(),
                'locked' => $card->nfc_locked,
            ],
            'card_url' => $this->when(
                $request->user()?->hasPermission('cards.write_nfc') ?? false,
                static fn (): string => app(CardUrlBuilder::class)->url($card),
            ),
            'last_used_at' => $card->last_used_at?->toIso8601String(),
            'created_at' => $card->created_at->toIso8601String(),
            'updated_at' => $card->updated_at->toIso8601String(),
        ];
    }
}
