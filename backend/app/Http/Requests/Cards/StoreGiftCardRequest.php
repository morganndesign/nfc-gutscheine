<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Enums\NfcTagType;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

final class StoreGiftCardRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'value' => ['required', 'integer', 'min:1', 'max:100000000'],
            'expires_at' => ['nullable', 'date_format:Y-m-d', 'after:today'],
            'customer_id' => ['nullable', 'uuid', $this->existsInTenant('customers')],
            'customer' => ['nullable', 'array', 'prohibits:customer_id'],
            'customer.first_name' => ['nullable', 'string', 'max:100'],
            'customer.last_name' => ['nullable', 'string', 'max:100'],
            'customer.email' => ['nullable', 'email:rfc', 'max:191'],
            'customer.phone' => ['nullable', 'string', 'max:40'],
            'customer.marketing_consent' => ['nullable', 'boolean'],
            'recipient_name' => ['nullable', 'string', 'max:160'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'activate' => ['sometimes', 'boolean'],
            'nfc_tag_type' => ['nullable', Rule::enum(NfcTagType::class)],
        ];
    }
}
