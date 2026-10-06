<?php

declare(strict_types=1);

namespace App\Providers;

use App\Enums\Permission;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Auth\DeviceTokenService;
use App\Services\Online\PaymentProvider;
use App\Services\Online\StripeProvider;
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

        // One verifier per presentment method (architecture §10.1). live_auth joins with the crypto service.
        $this->app->tag([PrintableQrVerifier::class], PresentmentVerifier::class);
        $this->app->when(PresentmentService::class)
            ->needs('$verifiers')
            ->giveTagged(PresentmentVerifier::class);

        // Online sales: Stripe Connect (decision 2026-10-06); another provider implements the same contract.
        $this->app->bind(PaymentProvider::class, StripeProvider::class);
    }

    public function boot(): void
    {
        EnvironmentGuard::assertPublicUrls((string) $this->app->environment(), [
            'app.url' => config('app.url'),
            'giftcard.frontend_url' => config('giftcard.frontend_url'),
            'giftcard.tap_url' => config('giftcard.tap_url'),
        ]);
        EnvironmentGuard::assertCryptoKeystore((string) $this->app->environment(), (string) config('crypto.provider'), config('crypto.local.master_key'));

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

            // Platform administrators never authenticate with a token (audit S2), only with a session. The one
            // exception is the station token: bound to one registered device, personalisation only.
            if (! $user instanceof User) {
                return false;
            }
            if ($user->isPlatformAdmin()) {
                return $token->device_id !== null
                    && array_diff((array) $token->abilities, DeviceTokenService::STATION_ABILITIES) === []
                    && $user->isActive();
            }

            // Waiter app tokens of a deactivated account still identify the caller, so EnforceDeviceToken can answer
            // 401 ACCOUNT_DEACTIVATED instead of a generic 401; permissions stay denied (Gate checks isActive()).
            return $user->isActive() || $token->device_id !== null;
        });
    }

    private function configureRateLimiting(): void
    {
        RateLimiter::for('api', static fn (Request $request): Limit => Limit::perMinute(240)->by($request->user()?->getAuthIdentifier() ?? $request->ip()));

        RateLimiter::for('login', static fn (Request $request): array => [
            Limit::perMinute(5)->by(self::throttleEmail((string) $request->input('email')).'|'.$request->ip()),
            Limit::perMinute(30)->by('login-ip:'.$request->ip()),
        ]);

        // The e-mailed sign-in code: a code dies after 5 wrong tries anyway; this keeps one address from cycling
        // through many sign-ins.
        RateLimiter::for('login-code', static fn (Request $request): array => [
            Limit::perMinute(10)->by('login-code:'.(string) $request->input('login')),
            Limit::perMinute(30)->by('login-code-ip:'.$request->ip()),
        ]);

        RateLimiter::for('password-reset', static fn (Request $request): Limit => Limit::perMinute(5)->by($request->ip()));

        // Guest tap page: generous for real guests, a wall for URL guessing.
        RateLimiter::for('tap', static fn (Request $request): Limit => Limit::perMinute(30)->by('tap:'.$request->ip()));

        RateLimiter::for('app-config', static fn (Request $request): Limit => Limit::perMinute(60)->by($request->ip()));
        // Online shop, public: reading it, ordering from it (the order also limits per e-mail and address), and the
        // payment provider's events.
        RateLimiter::for('shop', static fn (Request $request): Limit => Limit::perMinute(120)->by('shop:'.$request->ip()));
        RateLimiter::for('online-order', static fn (Request $request): Limit => Limit::perMinute(10)->by('online-order:'.$request->ip()));
        RateLimiter::for('webhook', static fn (Request $request): Limit => Limit::perMinute(1200)->by('webhook:'.$request->ip()));

        // Per user *and* terminal: several phones may share one waiter login during a busy service.
        $perTerminal = static fn (Request $request): string => ($request->user()?->getAuthIdentifier() ?? $request->ip()).'|'.substr((string) $request->header('X-Device-Id'), 0, 64);

        RateLimiter::for('presentment', static fn (Request $request): Limit => Limit::perMinute(90)->by($perTerminal($request)));

        RateLimiter::for('voucher-operation', static fn (Request $request): Limit => Limit::perMinute(90)->by($perTerminal($request)));
        // Asking for the outcome of an earlier attempt: its own budget, so a phone with several unresolved
        // attempts never slows down real redemptions.
        RateLimiter::for('redemption-outcome', static fn (Request $request): Limit => Limit::perMinute(60)->by($perTerminal($request)));
    }

    /**
     * Canonical e-mail for the per-account login throttle. The bucket must cover every spelling that signs in
     * as the same account: the lookup matches under MySQL's utf8mb4_unicode_ci, which folds case, width, accents
     * and other compatibility forms, so "ｏwner@…", "ówner@…" and "owner@…" are one account. Keying on a plain
     * lower-case left them in separate buckets, so cycling fullwidth/accented letters handed an attacker a fresh
     * 5/min bucket per spelling and defeated the per-account limit. Compatibility-decompose, drop the combining
     * marks and lower-case to mirror that folding and collapse the variants back into one key.
     */
    private static function throttleEmail(string $email): string
    {
        if (class_exists(\Normalizer::class)) {
            $decomposed = \Normalizer::normalize($email, \Normalizer::FORM_KD);
            if ($decomposed !== false) {
                $email = (string) preg_replace('/\p{Mn}+/u', '', $decomposed);
            }
        }

        return Str::lower(trim($email));
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

        // Token in the URL fragment: never sent to a server, so never in an access log or Referer (audit L1).
        ResetPassword::createUrlUsing(static fn (User $user, string $token): string => config('giftcard.frontend_url')
            .'/reset-password#'.http_build_query(['token' => $token, 'email' => $user->email]));
    }
}
