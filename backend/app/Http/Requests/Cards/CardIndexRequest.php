<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Enums\GiftCardStatus;
use App\Http\Requests\ApiRequest;

final class CardIndexRequest extends ApiRequest
{
    public const SORTS = ['created_at', '-created_at', 'balance', '-balance', 'expires_at', '-expires_at', 'card_number', '-card_number', 'last_used_at', '-last_used_at'];

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'search' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', 'array'],
            'status.*' => ['string', 'in:'.implode(',', GiftCardStatus::values())],
            'customer_id' => ['nullable', 'uuid'],
            'created_from' => ['nullable', 'date'],
            'created_to' => ['nullable', 'date'],
            'expires_from' => ['nullable', 'date'],
            'expires_to' => ['nullable', 'date'],
            'min_balance' => ['nullable', 'integer', 'min:0'],
            'max_balance' => ['nullable', 'integer', 'min:0'],
            // NFC programming queue: `unprogrammed` = usable NTAG213/215/216 (or undecided) cards without a tag yet.
            'nfc_status' => ['nullable', 'in:unprogrammed,unverified,verified'],
            'card_number_after' => ['nullable', 'string', 'max:32'],
            'sort' => ['nullable', 'in:'.implode(',', self::SORTS)],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $status = $this->input('status');
        if (is_string($status)) {
            $this->merge(['status' => array_filter(explode(',', $status))]);
        }
    }
}
