<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\GiftCardStatus;
use App\Http\Controllers\Controller;
use App\Models\GiftCard;
use App\Services\GiftCards\CardUrlBuilder;
use App\Support\CardNumber;
use Illuminate\Http\JsonResponse;

/**
 * Anonymous balance check for card holders (the URL on the card opens this when scanned by a
 * customer's phone). Only non-personal data is returned; it can be disabled per restaurant.
 */
final class PublicCardController extends Controller
{
    public function show(string $token, CardUrlBuilder $urls): JsonResponse
    {
        $token = $urls->extractToken($token);
        abort_if($token === null, 404);

        /** @var GiftCard|null $card */
        $card = GiftCard::query()->withoutGlobalScopes()->with('restaurant.settings')->whereNull('deleted_at')->where('public_token', $token)->first();

        // Cards of suspended or closed restaurants are not disclosed.
        if ($card === null || $card->restaurant === null || ! $card->restaurant->isActive()) {
            abort(404);
        }

        $settings = $card->restaurant->settings;
        if (! $settings->public_balance_check) {
            return response()->json([
                'data' => [
                    'restaurant_name' => $card->restaurant->name,
                    'balance_visible' => false,
                ],
            ]);
        }

        $status = $card->status === GiftCardStatus::Active && $card->isExpiredByDate() ? GiftCardStatus::Expired : $card->status;

        return response()->json([
            'data' => [
                'restaurant_name' => $card->restaurant->name,
                'brand_color' => $settings->brand_color,
                'balance_visible' => true,
                'card_number' => CardNumber::mask($card->card_number),
                'status' => $status->value,
                'balance' => in_array($status, [GiftCardStatus::Replaced, GiftCardStatus::Expired], true) ? 0 : $card->balance,
                'currency' => $card->currency,
                'expires_at' => $card->expires_at?->toIso8601String(),
                'locale' => $card->restaurant->locale,
            ],
        ]);
    }
}
