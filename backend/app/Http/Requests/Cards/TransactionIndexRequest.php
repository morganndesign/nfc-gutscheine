<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Enums\TransactionType;
use App\Http\Requests\ApiRequest;

final class TransactionIndexRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'type' => ['nullable', 'array'],
            'type.*' => ['string', 'in:'.implode(',', TransactionType::values())],
            'gift_card_id' => ['nullable', 'uuid'],
            'user_id' => ['nullable', 'uuid'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
            'search' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $type = $this->input('type');
        if (is_string($type)) {
            $this->merge(['type' => array_filter(explode(',', $type))]);
        }
    }
}
