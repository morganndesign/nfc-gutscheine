<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Http\Requests\ApiRequest;

final class ReloadVoucherRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'amount' => ['required', 'integer:strict', 'min:1', 'max:100000000'],
            ...PaymentRules::rules(),
            'note' => ['nullable', 'string', 'max:500'],
            // The `reload` presentment of the guest's card when it is topped up at the till (the app).
            'presentment_id' => ['nullable', 'uuid'],
        ];
    }
}
