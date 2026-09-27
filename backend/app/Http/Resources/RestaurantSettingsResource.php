<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\RestaurantSetting;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin RestaurantSetting
 */
final class RestaurantSettingsResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var RestaurantSetting $s */
        $s = $this->resource;

        return [
            'card_number_prefix' => $s->card_number_prefix,
            'default_validity_months' => $s->default_validity_months,
            'min_card_value' => $s->min_card_value,
            'max_card_value' => $s->max_card_value,
            'max_card_balance' => $s->max_card_balance,
            'max_single_redemption' => $s->max_single_redemption,
            'max_redemptions_per_card_per_hour' => $s->max_redemptions_per_card_per_hour,
            'allow_reload' => $s->allow_reload,
            'allow_partial_redemption' => $s->allow_partial_redemption,
            'public_balance_check' => $s->public_balance_check,
            'enforce_nfc_uid_binding' => $s->enforce_nfc_uid_binding,
            'lock_nfc_tags_after_write' => $s->lock_nfc_tags_after_write,
            'send_customer_emails' => $s->send_customer_emails,
            'brand_color' => $s->brand_color,
            'receipt_footer' => $s->receipt_footer,
        ];
    }
}
