<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Http\Requests\ApiRequest;

final class CancelSaleRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'min:3', 'max:500'],
            // The terminal's cancellation receipt or the bank reference, when the sale was paid that way.
            'reference' => ['nullable', 'string', 'max:120'],
        ];
    }
}
