<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiRequest;

final class ConfirmLoginCodeRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'login' => ['required', 'uuid'],
            'code' => ['required', 'string', 'regex:/^\\s*\\d{3}\\s?\\d{3}\\s*$/'],
        ];
    }
}
