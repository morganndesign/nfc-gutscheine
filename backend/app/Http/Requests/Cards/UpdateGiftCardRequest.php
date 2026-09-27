<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class UpdateGiftCardRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'customer_id' => ['sometimes', 'nullable', 'uuid', $this->existsInTenant('customers')],
            'recipient_name' => ['sometimes', 'nullable', 'string', 'max:160'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'expires_at' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'after:today'],
        ];
    }
}
