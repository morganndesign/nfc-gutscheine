<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;

final class ResolveCardBatchHoldRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // Inventory numbers of the cards that are really missing; every other delivered card becomes available.
            'missing' => ['present', 'array', 'max:100000'],
            'missing.*' => ['string', 'max:32', 'distinct'],
        ];
    }
}
