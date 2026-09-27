<?php

declare(strict_types=1);

namespace App\Http\Requests\Settings;

use App\Http\Requests\ApiRequest;

final class UpdateCardSettingsRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'card_number_prefix' => ['sometimes', 'nullable', 'string', 'regex:/^[1-9][0-9]{0,5}$/'],
            'default_validity_months' => ['sometimes', 'integer', 'min:0', 'max:360'],
            'min_card_value' => ['sometimes', 'integer', 'min:1'],
            'max_card_value' => ['sometimes', 'integer', 'min:1', 'max:100000000'],
            'max_card_balance' => ['sometimes', 'integer', 'min:1', 'max:100000000'],
            'max_single_redemption' => ['sometimes', 'nullable', 'integer', 'min:1'],
            'max_redemptions_per_card_per_hour' => ['sometimes', 'integer', 'min:0', 'max:1000'],
            'allow_reload' => ['sometimes', 'boolean'],
            'allow_partial_redemption' => ['sometimes', 'boolean'],
            'public_balance_check' => ['sometimes', 'boolean'],
            'enforce_nfc_uid_binding' => ['sometimes', 'boolean'],
            'lock_nfc_tags_after_write' => ['sometimes', 'boolean'],
            'send_customer_emails' => ['sometimes', 'boolean'],
            'brand_color' => ['sometimes', 'string', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'receipt_footer' => ['sometimes', 'nullable', 'string', 'max:500'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('card_number_prefix') && $this->input('card_number_prefix') === null) {
            $this->merge(['card_number_prefix' => '']);
        }
    }
}
