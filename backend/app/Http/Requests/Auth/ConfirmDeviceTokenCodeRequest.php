<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiRequest;

/** Waiter app sign-in, step 2: the e-mailed code, from the phone that asked for it. */
final class ConfirmDeviceTokenCodeRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'login' => ['required', 'uuid'],
            'code' => ['required', 'string', 'regex:/^\\s*\\d{3}\\s?\\d{3}\\s*$/'],
            'device_id' => ['required', 'string', 'regex:/^[A-Za-z0-9\\-]{16,64}$/'],
            'device_name' => ['required', 'string', 'max:60'],
            'platform' => ['required', 'string', 'in:android,ios'],
        ];
    }
}
