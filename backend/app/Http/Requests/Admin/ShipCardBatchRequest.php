<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;

final class ShipCardBatchRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'tracking_ref' => ['nullable', 'string', 'max:120'],
        ];
    }
}
