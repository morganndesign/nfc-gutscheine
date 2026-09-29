<?php

declare(strict_types=1);

namespace App\Providers;

use App\Enums\Permission;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Nfc\Ntag424SunVerifier;
use App\Services\Presentments\PresentmentService;
use App\Services\Presentments\PresentmentVerifier;
use App\Services\Presentments\PrintableQrVerifier;
use App\Support\EnvironmentGuard;
use App\Support\Tenancy\TenantContext;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;
use Laravel\Sanctum\Sanctum;

final class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Request-scoped: reset for every request / queued job (safe under Octane and queue workers).
        $this->app->scoped(TenantContext::class);
        $this->app->singleton(Ntag424SunVerifier::class, static fn (): Ntag424SunVerifier => Ntag424SunVerifier::fromConfig());

        // One verifier per presentment method (architecture §10.1). live_auth joins with the crypto service.
        $this->app->tag([PrintableQrVerifier::class], PresentmentVerifier::class);
        $this->app->when(PresentmentService::class)
            ->needs('$verifiers')
            ->giveTagged(PresentmentVerifier::class);
    }

    public function boot(): void
    {
        EnvironmentGuard::assertPublicUrls((string) $this->app->environment(), [
            'app.url' => config('app.url'),
            'giftcard.frontend_url' => config('giftcard.frontend_url'),
        ]);

        Model::preventLazyLoading(! $this->app->isProduction());
        Model::preventSilentlyDiscardingAttributes(! $this->app->isProduction());
        Model::automaticallyEagerLoadRelationships();

        $this->configureAuthorization();
        $this->configureSanctum();
        $this->configureRateLimiting();
        $this->configureRouteBindings();
        $this->configurePasswords();

        // Listeners in app/Listeners are registered by Laravel's event discovery (see `php artisan event:list`).
    }

    private function configureAuthorization(): void
    {
        $permissions = array_flip(Permission::values());

        // Permission strings ("vouchers.redeem") are resolved against the user's role (and token abilities).
        Gate::before(static function (User $user, string $ability) use ($permissions): ?bool {
            if (! isset($permissions[$ability])) {
                return null;
            }

            return $user->isActive() && $user->hasPermission($ability);
        });
    }

    private function configureSanctum(): void
    {
        Sanctum::usePersonalAccessTokenModel(PersonalAccessToken::class);

        Sanctum::authenticateAccessTokensUsing(static function (PersonalAccessToken $token, bool $isValid): bool {
            if (! $isValid || ! $token->isUsable()) {
                return false;
            }

            $user = $token->tokenable;

            // Waiter app tokens of a deactivated account still identify the caller, so EnforceDeviceToken can answer
            // 401 ACCOUNT_DEACTIVATED instead of a generic 401; permissions stay denied (Gate checks isActive()).
            return $user instanceof User && ($user->isActive() || $token->device_id !== null);
        });
    }

    private function configureRateLimiting(): void
    {
        RateLimiter::for('api', static fn (Request $request): Limit => Limit::perMinute(240)->by($request->user()?->getAuthIdentifier() ?? $request->ip()));

        RateLimiter::for('login', static fn (Request $request): array => [
            Limit::perMinute(5)->by(Str::lower((string) $request->input('email')).'|'.$request->ip()),
            Limit::perMinute(30)->by('login-ip:'.$request->ip()),
        ]);

        RateLimiter::for('password-reset', static fn (Request $request): Limit => Limit::perMinute(5)->by($request->ip()));

        RateLimiter::for('app-config', static fn (Request $request): Limit => Limit::perMinute(60)->by($request->ip()));

        // Per user *and* terminal: several phones may share one waiter login during a busy service.
        $perTerminal = static fn (Request $request): string => ($request->user()?->getAuthIdentifier() ?? $request->ip()).'|'.substr((string) $request->header('X-Device-Id'), 0, 64);

        RateLimiter::for('presentment', static fn (Request $request): Limit => Limit::perMinute(90)->by($perTerminal($request)));

        RateLimiter::for('voucher-operation', static fn (Request $request): Limit => Limit::perMinute(90)->by($perTerminal($request)));
    }

    private function configureRouteBindings(): void
    {
        Route::bind('voucher', static fn (string $value): Voucher => Str::isUuid($value)
            ? Voucher::query()->findOrFail($value)
            : abort(404));

        // Staff can only ever be resolved within the current restaurant.
        Route::bind('user', static function (string $value): User {
            abort_unless(Str::isUuid($value), 404);
            $tenant = app(TenantContext::class);

            /** @var User */
            return User::query()
                ->when($tenant->has(), static fn ($q) => $q->where('restaurant_id', $tenant->id()))
                ->findOrFail($value);
        });

        foreach (['transaction', 'customer', 'device', 'restaurant'] as $parameter) {
            Route::pattern($parameter, '[0-9a-fA-F\-]{36}');
        }
    }

    private function configurePasswords(): void
    {
        Password::defaults(static fn (): Password => app()->isProduction()
            ? Password::min(12)->mixedCase()->numbers()->uncompromised()
            : Password::min(10)->mixedCase()->numbers());

        ResetPassword::createUrlUsing(static fn (User $user, string $token): string => config('giftcard.frontend_url')
            .'/reset-password?token='.urlencode($token).'&email='.urlencode($user->email));
    }
}
