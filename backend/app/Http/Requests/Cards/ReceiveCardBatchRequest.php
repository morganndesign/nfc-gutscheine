<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class ReceiveCardBatchRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // The number of cards counted in the parcel.
            'count' => ['required', 'integer:strict', 'min:0', 'max:100000'],
            // The `receive` presentment of one card of this batch, tapped by the person confirming.
            'presentment_id' => ['required', 'uuid'],
        ];
    }
}
