<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiRequest;
use Closure;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

final class ChangePasswordRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'current_password' => ['required', 'string', function (string $attribute, mixed $value, Closure $fail): void {
                if (! is_string($value) || ! Hash::check($value, (string) $this->user()?->getAuthPassword())) {
                    $fail(__('validation.current_password'));
                }
            }],
            'password' => ['required', 'string', 'confirmed', 'different:current_password', Password::defaults()],
        ];
    }
}
