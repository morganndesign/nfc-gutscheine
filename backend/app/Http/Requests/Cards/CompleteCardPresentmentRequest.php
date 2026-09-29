<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class CompleteCardPresentmentRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // The card's answer to part 2, with its status word (32 bytes + 91 00).
            'response' => ['required', 'string', 'regex:/^[0-9A-Fa-f]{68}$/'],
        ];
    }
}
