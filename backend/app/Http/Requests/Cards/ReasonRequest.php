<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class ReasonRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return ['reason' => ['required', 'string', 'min:3', 'max:500']];
    }
}
