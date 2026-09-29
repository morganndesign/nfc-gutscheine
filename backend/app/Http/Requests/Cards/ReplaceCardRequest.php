<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class ReplaceCardRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // The `bind` presentment of the new card (a stock card, tapped for this replacement).
            'presentment_id' => ['required', 'uuid'],
            'reason' => ['required', 'string', 'min:3', 'max:120'],
        ];
    }
}
