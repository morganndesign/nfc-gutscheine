<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

/** Step 2 of programming: the chip serial number and the link currently stored on the tag. */
final class CheckNfcTagRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'attempt_id' => ['required', 'uuid'],
            'uid' => ['required', 'string', 'max:40', NfcUidRule::closure()],
            'current_url' => ['nullable', 'string', 'max:2048'],
            'only_if_unprogrammed' => ['sometimes', 'boolean'],
        ];
    }
}
