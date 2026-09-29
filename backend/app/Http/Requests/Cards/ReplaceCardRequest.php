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
            // The `surrender` presentment of the old card when it is at hand (damaged); without it (lost, stolen) the
            // replacement needs cards.replace_lost.
            'surrender_presentment_id' => ['nullable', 'uuid', 'different:presentment_id'],
            'reason' => ['required', 'string', 'min:3', 'max:120'],
        ];
    }
}
