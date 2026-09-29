<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class BeginPersonalizationRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // The 7-byte UID the chip gave in anticollision (the phone's tag id).
            'rf_uid' => ['required', 'string', 'regex:/^[0-9A-Fa-f]{14}$/'],
        ];
    }
}
