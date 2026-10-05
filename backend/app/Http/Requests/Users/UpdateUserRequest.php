<?php

declare(strict_types=1);

namespace App\Http\Requests\Users;

use App\Enums\RoleSlug;
use App\Http\Requests\ApiRequest;
use App\Models\User;
use Illuminate\Validation\Rule;

final class UpdateUserRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        /** @var User $user */
        $user = $this->route('user');

        return [
            'name' => ['sometimes', 'required', 'string', 'max:160'],
            'email' => ['sometimes', 'required', 'email:rfc', 'max:191', Rule::unique('users', 'email')->ignore($user->getKey())],
            'role' => ['sometimes', 'required', Rule::in([RoleSlug::Owner->value, RoleSlug::Manager->value, RoleSlug::Waiter->value])],
            'locale' => ['sometimes', 'required', 'in:de,en,bs'],
            // Changing one's own e-mail address (UserService::update).
            'current_password' => ['sometimes', 'string', 'max:255'],
        ];
    }
}
