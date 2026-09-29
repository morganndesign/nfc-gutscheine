<?php

declare(strict_types=1);

namespace App\Http\Requests;

final class OptionalReasonRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return ['reason' => ['nullable', 'string', 'max:500']];
    }
}
