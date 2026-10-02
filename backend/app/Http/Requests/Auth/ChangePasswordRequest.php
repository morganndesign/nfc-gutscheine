<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiRequest;
use App\Models\User;
use Closure;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Laravel\Sanctum\TransientToken;

final class ChangePasswordRequest extends ApiRequest
{
    /**
     * Only the person in a signed-in browser (a session) changes the password. The current-password check would
     * otherwise be a password oracle for every access token: an integration token could guess the password and, on a
     * hit, set its own and sign in with all of the role's rights. Waiter app tokens never reach this route anyway.
     */
    public function authorize(): bool
    {
        $user = $this->user();

        return $user instanceof User && $user->currentAccessToken() instanceof TransientToken;
    }

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
