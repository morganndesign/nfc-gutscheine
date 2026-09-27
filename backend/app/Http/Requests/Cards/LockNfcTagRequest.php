<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class LockNfcTagRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return ['attempt_id' => ['required', 'uuid']];
    }
}
