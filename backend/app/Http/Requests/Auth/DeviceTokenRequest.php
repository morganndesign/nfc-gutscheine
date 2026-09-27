<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

final class DeviceTokenRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, list<string>> */
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email:rfc', 'max:191'],
            'password' => ['required', 'string', 'max:255'],
            'device_id' => ['required', 'string', 'regex:/^[A-Za-z0-9\-]{16,64}$/'],
            'device_name' => ['required', 'string', 'max:60'],
            'platform' => ['required', 'string', 'in:android,ios'],
        ];
    }
}
