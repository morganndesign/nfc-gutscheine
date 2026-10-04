<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\SecurityEventType;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ConfirmLoginCodeRequest;
use App\Http\Requests\Auth\DeviceTokenRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\ResendLoginCodeRequest;
use App\Http\Resources\RestaurantSettingsResource;
use App\Models\PersonalAccessToken;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Auth\CredentialVerifier;
use App\Services\Auth\DeviceTokenService;
use App\Services\Auth\LoginCodeService;
use App\Services\Security\AuthEvents;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;

final class AuthController extends Controller
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly CredentialVerifier $credentials,
        private readonly DeviceTokenService $deviceTokens,
        private readonly AuthEvents $authEvents,
        private readonly SecurityEventRecorder $events,
        private readonly LoginCodeService $loginCodes,
    ) {}

    /**
     * Dashboard sign-in, step 1: the password. A browser trusted for this user (a code confirmed within 15 days)
     * is signed in at once; any other gets a 6-digit code by e-mail and the answer 202 with the sign-in to
     * confirm (decision 2026-10-05).
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = $this->credentials->verify($request, (string) $request->validated('email'), (string) $request->validated('password'));

        if ($this->loginCodes->isTrusted($request, $user)) {
            return $this->signIn($request, $user, $request->boolean('remember'));
        }

        $login = $this->loginCodes->start($user, $request->boolean('remember'));

        return response()->json(['data' => [
            'code_required' => true,
            'login' => $login->id,
            'email' => LoginCodeService::maskEmail($user->email),
            'expires_in' => (int) config('giftcard.security.login_code_minutes') * 60,
        ]], 202);
    }

    /** Step 2: the code from the e-mail. Signs in and trusts this browser for 15 days. */
    public function confirmCode(ConfirmLoginCodeRequest $request): JsonResponse
    {
        $login = $this->loginCodes->confirm($request, (string) $request->validated('login'), (string) $request->validated('code'));

        return $this->signIn($request, $login->user, $login->remember)
            ->withCookie($this->loginCodes->trust($request, $login->user));
    }

    /** "Send a new code" for the same sign-in. */
    public function resendCode(ResendLoginCodeRequest $request): JsonResponse
    {
        $this->loginCodes->resend((string) $request->validated('login'));

        return response()->json(['message' => 'sent']);
    }

    private function signIn(Request $request, User $user, bool $remember): JsonResponse
    {
        Auth::guard('web')->login($user, $remember);
        if ($request->hasSession()) {
            $request->session()->regenerate();
        }

        $this->audit->log('auth.login', Actor::fromRequest($request), $user, restaurantId: $user->restaurant_id);
        $this->authEvents->signedIn($request, $user, 'web');

        return response()->json(['data' => $this->profile($user)]);
    }

    /** Sign-in for the native waiter app: a device-bound bearer token (present and redeem vouchers; managers and owners also sell them). */
    public function token(DeviceTokenRequest $request): JsonResponse
    {
        $user = $this->credentials->verify($request, (string) $request->validated('email'), (string) $request->validated('password'), deviceClient: true);

        $token = $this->deviceTokens->issue(
            $request,
            $user,
            (string) $request->validated('device_id'),
            (string) $request->validated('device_name'),
            (string) $request->validated('platform'),
        );

        $this->authEvents->signedIn($request, $user, 'app');

        /** @var PersonalAccessToken $model */
        $model = $token->accessToken;
        // The profile's permissions then reflect the token's abilities (DeviceTokenService::abilitiesFor).
        $user->withAccessToken($model);

        return response()->json([
            'data' => [
                'token' => $token->plainTextToken,
                'expires_at' => $model->expires_at?->toIso8601String(),
                'user' => $this->profile($user),
            ],
        ], 201);
    }

    public function logout(Request $request): JsonResponse
    {
        $user = $this->user($request);
        $token = $user->currentAccessToken();

        if ($token instanceof PersonalAccessToken) {
            $token->forceFill(['revoked_at' => Carbon::now(), 'revoked_by' => $user->getKey()])->save();
        } else {
            Auth::guard('web')->logout();
            if ($request->hasSession()) {
                $request->session()->invalidate();
                $request->session()->regenerateToken();
            }
        }

        $this->audit->log('auth.logout', Actor::fromRequest($request), $user, restaurantId: $user->restaurant_id);
        $this->events->record(SecurityEventType::SignOut, Actor::fromRequest($request), subject: $user, data: [
            'channel' => $token instanceof PersonalAccessToken ? 'app' : 'web',
        ]);

        return response()->json(['message' => 'Logged out.']);
    }

    /** The user's language for the dashboard and the waiter app (de, en, bs). */
    public function language(Request $request): JsonResponse
    {
        $locale = (string) $request->validate(['locale' => ['required', 'string', 'in:de,en,bs']])['locale'];
        $user = $this->user($request);
        if ($user->locale !== $locale) {
            $old = $user->locale;
            $user->forceFill(['locale' => $locale])->save();
            $this->audit->log('user.profile_updated', Actor::fromRequest($request), $user, ['locale' => $old], ['locale' => $locale], restaurantId: $user->restaurant_id);
        }

        return response()->json(['data' => ['locale' => $user->locale]]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->profile($this->user($request))]);
    }

    /** @return array<string, mixed> */
    private function profile(User $user): array
    {
        $user->loadMissing(['role', 'restaurant.settings']);
        $tenant = app(TenantContext::class)->restaurant() ?? $user->restaurant;

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'locale' => $user->locale,
            'role' => ['slug' => $user->role->slug->value, 'name' => $user->role->name],
            'is_platform_admin' => $user->isPlatformAdmin(),
            'permissions' => $user->effectivePermissions(),
            'restaurant' => $tenant !== null ? [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'slug' => $tenant->slug,
                'currency' => $tenant->currency,
                'timezone' => $tenant->timezone,
                'locale' => $tenant->locale,
                'status' => $tenant->status->value,
                'is_test' => $tenant->is_test,
                'settings' => RestaurantSettingsResource::make($tenant->settings)->resolve(),
            ] : null,
            'platform' => [
                'support_email' => SystemSetting::get('platform.support_email'),
                'notice' => SystemSetting::get('platform.maintenance_notice'),
            ],
        ];
    }
}
