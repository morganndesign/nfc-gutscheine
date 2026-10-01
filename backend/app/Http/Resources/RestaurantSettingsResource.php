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
            'validity_months' => $s->validity_months,
            'min_voucher_value' => $s->min_voucher_value,
            'max_voucher_balance' => $s->max_voucher_balance,
            'max_debit_per_transaction' => $s->max_debit_per_transaction,
            'max_debit_per_voucher_per_day' => $s->max_debit_per_voucher_per_day,
            'max_redemptions_per_voucher_per_hour' => $s->max_redemptions_per_voucher_per_hour,
            'allow_reload' => $s->allow_reload,
            'allow_partial_redemption' => $s->allow_partial_redemption,
            'send_customer_emails' => $s->send_customer_emails,
            'public_balance' => $s->public_balance,
            'brand_color' => $s->brand_color,
            'receipt_footer' => $s->receipt_footer,
            'voucher_design' => [
                'template' => $s->voucher_template,
                'format' => $s->voucher_format,
                'accent_color' => $s->accent_color,
                'headline' => $s->voucher_headline,
                'message' => $s->voucher_message,
            ],
            // Versioned: the URL changes when the logo does, so clients may cache it for good.
            'logo_url' => $s->logo_version !== null ? '/api/v1/restaurant/logo?v='.substr($s->logo_version, 0, 16) : null,
            'platform_limits' => [
                'max_voucher_balance' => (int) config('giftcard.limits.max_voucher_balance'),
                'max_debit_per_transaction' => (int) config('giftcard.limits.max_debit_per_transaction'),
                'max_debit_per_voucher_per_day' => (int) config('giftcard.limits.max_debit_per_voucher_per_day'),
                'min_validity_months' => (int) config('giftcard.limits.min_validity_months'),
            ],
        ];
    }
}
