<?php

declare(strict_types=1);

namespace App\Http\Requests\Users;

use App\Enums\RoleSlug;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

final class StoreUserRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:160'],
            'email' => ['required', 'email:rfc', 'max:191', Rule::unique('users', 'email')],
            'role' => ['required', Rule::in([RoleSlug::Owner->value, RoleSlug::Manager->value, RoleSlug::Waiter->value])],
            'password' => ['nullable', 'string', Password::defaults()],
            'locale' => ['nullable', 'in:de,en,bs'],
        ];
    }
}
