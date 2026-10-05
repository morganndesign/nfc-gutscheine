<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

/** Resume a suspended card: the reason and the tap of the card itself (decision 2026-10-06, K4). */
final class ResumeCardRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'min:3', 'max:120'],
            'presentment_id' => ['required', 'uuid'],
        ];
    }
}
