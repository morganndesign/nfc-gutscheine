<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Validation\Rule;

/** Optional corrections of a not yet accepted invitation (a mistyped name or e-mail address). */
final class ResendInvitationRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        $user = $this->route('user');
        if (! $user instanceof User) {
            $restaurant = $this->route('restaurant');
            $user = $restaurant instanceof Restaurant ? $restaurant->owner()->first() : null;
        }

        return [
            'name' => ['sometimes', 'nullable', 'string', 'max:160'],
            'email' => ['sometimes', 'nullable', 'email:rfc', 'max:191', Rule::unique('users', 'email')->ignore($user?->getKey())],
        ];
    }
}
