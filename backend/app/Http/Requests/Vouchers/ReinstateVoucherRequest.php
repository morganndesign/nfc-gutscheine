<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Http\Requests\ApiRequest;

final class ReinstateVoucherRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'min:3', 'max:500'],
            // New last valid day in the restaurant's timezone; null or missing = no expiry.
            'expires_on' => ['nullable', 'date_format:Y-m-d', 'after:today'],
        ];
    }
}
