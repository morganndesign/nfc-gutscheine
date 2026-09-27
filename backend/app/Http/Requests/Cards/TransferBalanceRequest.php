<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class TransferBalanceRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'target_card_id' => ['required_without:target_card_number', 'nullable', 'uuid', $this->existsInTenant('gift_cards')],
            'target_card_number' => ['required_without:target_card_id', 'nullable', 'string', 'max:30'],
            'amount' => ['nullable', 'integer', 'min:1', 'max:100000000'],
            'note' => ['nullable', 'string', 'max:500'],
        ];
    }
}
