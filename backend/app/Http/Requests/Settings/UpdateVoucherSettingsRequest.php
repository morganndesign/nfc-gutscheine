<?php

declare(strict_types=1);

namespace App\Http\Requests\Settings;

use App\Http\Requests\ApiRequest;

final class UpdateVoucherSettingsRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        $limits = (array) config('giftcard.limits');

        return [
            // Null = no expiry. A limited validity below three years is not admissible for paid vouchers in
            // Austria (OGH 7 Ob 22/12d; audit P6), so the platform refuses it.
            'validity_months' => ['sometimes', 'nullable', 'integer:strict', 'min:'.$limits['min_validity_months'], 'max:360'],
            'min_voucher_value' => ['sometimes', 'integer:strict', 'min:1'],
            'max_voucher_balance' => ['sometimes', 'integer:strict', 'min:1', 'max:'.$limits['max_voucher_balance']],
            'max_debit_per_transaction' => ['sometimes', 'integer:strict', 'min:1', 'max:'.$limits['max_debit_per_transaction']],
            'max_debit_per_voucher_per_day' => ['sometimes', 'integer:strict', 'min:1', 'max:'.$limits['max_debit_per_voucher_per_day']],
            'max_redemptions_per_voucher_per_hour' => ['sometimes', 'integer:strict', 'min:0', 'max:1000'],
            'allow_reload' => ['sometimes', 'boolean:strict'],
            'allow_partial_redemption' => ['sometimes', 'boolean:strict'],
            'send_customer_emails' => ['sometimes', 'boolean:strict'],
            'public_balance' => ['sometimes', 'boolean:strict'],
            'brand_color' => ['sometimes', 'string', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'receipt_footer' => ['sometimes', 'nullable', 'string', 'max:500'],
            'voucher_template' => ['sometimes', 'string', 'in:classic,minimal,bold,elegant'],
            'voucher_format' => ['sometimes', 'string', 'in:a4,a5,a6'],
            'accent_color' => ['sometimes', 'string', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'voucher_headline' => ['sometimes', 'nullable', 'string', 'max:60'],
            'voucher_message' => ['sometimes', 'nullable', 'string', 'max:240'],
        ];
    }
}
