<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Enums\GiftCardStatus;
use App\Models\GiftCard;
use App\Models\User;
use App\Support\CardNumber;
use App\Support\Tenancy\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Minimal card view for the waiter app: exactly what is needed to redeem, plus the
 * actions this user may perform on this card right now. No customer data.
 *
 * @mixin GiftCard
 */
final class ScannedCardResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var GiftCard $card */
        $card = $this->resource;
        /** @var User $user */
        $user = $request->user();
        $restaurant = app(TenantContext::class)->require();

        $usable = $card->status === GiftCardStatus::Active && ! $card->isExpiredByDate();
        $reloadable = in_array($card->status, [GiftCardStatus::Active, GiftCardStatus::Redeemed, GiftCardStatus::Inactive], true)
            && ! $card->isExpiredByDate() && $restaurant->settings->allow_reload;

        return [
            'id' => $card->id,
            'restaurant_name' => $restaurant->name,
            'card_number' => CardNumber::format($card->card_number),
            'status' => $card->status->value,
            'currency' => $card->currency,
            'balance' => $card->balance,
            'expires_at' => $card->expires_at?->toIso8601String(),
            'is_expired' => $card->isExpiredByDate(),
            'blocked_reason' => $card->status === GiftCardStatus::Blocked ? $card->blocked_reason : null,
            'allow_partial_redemption' => $restaurant->settings->allow_partial_redemption,
            'actions' => [
                'redeem' => $usable && $card->balance > 0 && $user->hasPermission('cards.redeem'),
                'reload' => $reloadable && $user->hasPermission('cards.reload'),
                'history' => $user->hasPermission('cards.view'),
                'block' => in_array($card->status, [GiftCardStatus::Active, GiftCardStatus::Inactive, GiftCardStatus::Redeemed], true)
                    && $user->hasPermission('cards.block'),
                'activate' => $card->status === GiftCardStatus::Inactive && $user->hasPermission('cards.activate'),
            ],
        ];
    }
}
