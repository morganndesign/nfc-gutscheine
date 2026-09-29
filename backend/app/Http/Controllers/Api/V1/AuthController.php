<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\DeviceTokenRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Resources\RestaurantSettingsResource;
use App\Models\PersonalAccessToken;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Auth\CredentialVerifier;
use App\Services\Auth\DeviceTokenService;
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
    ) {}

    public function login(LoginRequest $request): JsonResponse
    {
        $user = $this->credentials->verify($request, (string) $request->validated('email'), (string) $request->validated('password'));

        Auth::guard('web')->login($user, $request->boolean('remember'));
        if ($request->hasSession()) {
            $request->session()->regenerate();
        }

        $this->audit->log('auth.login', Actor::fromRequest($request), $user, restaurantId: $user->restaurant_id);

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

        return response()->json(['message' => 'Logged out.']);
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
                'settings' => RestaurantSettingsResource::make($tenant->settings)->resolve(),
            ] : null,
            'platform' => [
                'support_email' => SystemSetting::get('platform.support_email'),
                'notice' => SystemSetting::get('platform.maintenance_notice'),
            ],
        ];
    }
}
