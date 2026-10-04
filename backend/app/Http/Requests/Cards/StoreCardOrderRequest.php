<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;
use App\Services\Cards\CardOrderService;

final class StoreCardOrderRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'quantity' => ['required', 'integer:strict', 'min:1', 'max:'.CardOrderService::MAX_QUANTITY],
            'note' => ['nullable', 'string', 'max:500'],
        ];
    }
}
