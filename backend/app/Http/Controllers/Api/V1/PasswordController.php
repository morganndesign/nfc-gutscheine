<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Users\UserService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class PasswordController extends Controller
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly UserService $users,
    ) {}

    public function forgot(ForgotPasswordRequest $request): JsonResponse
    {
        Password::broker()->sendResetLink(['email' => Str::lower((string) $request->validated('email'))]);

        // Always the same answer, so the endpoint cannot be used to enumerate accounts.
        return response()->json(['message' => 'If an account exists for this address, a password reset link has been sent.']);
    }

    public function reset(ResetPasswordRequest $request): JsonResponse
    {
        // Invitation links (72 h) and "forgot password" links (60 min) share the token table but not the lifetime.
        $email = Str::lower((string) $request->validated('email'));
        $invited = User::query()->where('email', $email)->first();
        $broker = $invited !== null && UserService::isPendingInvitation($invited) ? 'invitations' : 'users';

        $status = Password::broker($broker)->reset(
            [
                'email' => $email,
                'password' => (string) $request->validated('password'),
                'password_confirmation' => (string) $request->input('password_confirmation'),
                'token' => (string) $request->validated('token'),
            ],
            function (User $user, string $password) use ($request): void {
                $user->forceFill([
                    'password' => $password,
                    'remember_token' => Str::random(60),
                    'password_changed_at' => Carbon::now(),
                    'failed_login_attempts' => 0,
                    'locked_until' => null,
                    'email_verified_at' => $user->email_verified_at ?? Carbon::now(),
                ])->save();

                $this->audit->log('auth.password_reset', new Actor($user, null, $request->ip(), (string) $request->userAgent()), $user, restaurantId: $user->restaurant_id);
            },
        );

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages(['email' => __($status)]);
        }

        return response()->json(['message' => __($status)]);
    }

    public function change(ChangePasswordRequest $request): JsonResponse
    {
        $user = $this->user($request);
        $this->users->changePassword(Actor::fromRequest($request), $user, (string) $request->validated('password'));

        if ($request->hasSession()) {
            $request->session()->regenerate();
        }

        return response()->json(['message' => 'Password updated.']);
    }

    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $user = $this->user($request);
        $user->fill($request->validated());

        if ($user->isDirty()) {
            $old = array_intersect_key($user->getOriginal(), $user->getDirty());
            $new = $user->getDirty();
            $user->save();
            $this->audit->log('user.profile_updated', Actor::fromRequest($request), $user, $old, $new, restaurantId: $user->restaurant_id);
        }

        return response()->json(['data' => ['name' => $user->name, 'locale' => $user->locale]]);
    }
}
