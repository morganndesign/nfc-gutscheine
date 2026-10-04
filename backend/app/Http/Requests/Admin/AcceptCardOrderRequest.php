<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;

final class AcceptCardOrderRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // Who prints the cards; empty = printed in-house.
            'manufacturer' => ['nullable', 'string', 'max:120'],
            // Another quantity than ordered (agreed with the restaurant); empty = as ordered.
            'quantity' => ['nullable', 'integer:strict', 'min:1', 'max:100000'],
        ];
    }
}
