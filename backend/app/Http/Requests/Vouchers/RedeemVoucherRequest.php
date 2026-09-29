<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Http\Requests\ApiRequest;

final class RedeemVoucherRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // Minor units; strict integers only (audit P9).
            'amount' => ['required', 'integer:strict', 'min:1', 'max:100000000'],
            // The proof that the voucher's medium is here, now (architecture §10.6).
            'presentment_id' => ['required', 'uuid'],
            'reference' => ['nullable', 'string', 'max:120'],
            'note' => ['nullable', 'string', 'max:500'],
        ];
    }
}
