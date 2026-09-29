<?php

declare(strict_types=1);

use App\Exceptions\Domain\DomainException;
use App\Http\Middleware\AssignRequestId;
use App\Http\Middleware\BindRememberedSignIn;
use App\Http\Middleware\EnforceDeviceToken;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Middleware\RequireTenant;
use App\Http\Middleware\ResolveTenant;
use App\Http\Middleware\SecurityHeaders;
use App\Http\Middleware\TrackDevice;
use App\Services\Security\AuthEvents;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Auth\Middleware\Authorize;
use Illuminate\Contracts\Auth\Middleware\AuthenticatesRequests;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Session\TokenMismatchException;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->statefulApi();
        // Only the reverse proxy (Caddy on the private Docker network) may set X-Forwarded-* headers;
        // anything else could spoof client IPs and bypass IP-based rate limits.
        $middleware->trustProxies(at: ['127.0.0.1', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', 'fd00::/8']);
        $middleware->prepend(AssignRequestId::class);
        $middleware->append(SecurityHeaders::class);

        $middleware->alias([
            'tenant' => ResolveTenant::class,
            'tenant.required' => RequireTenant::class,
            'device' => TrackDevice::class,
            'device.token' => EnforceDeviceToken::class,
            'remembered' => BindRememberedSignIn::class,
            'idempotent' => RequireIdempotencyKey::class,
        ]);

        // Order matters: authenticate → tenant → everything else.
        $middleware->priority([
            EncryptCookies::class,
            StartSession::class,
            EnsureFrontendRequestsAreStateful::class,
            AuthenticatesRequests::class,
            BindRememberedSignIn::class,
            EnforceDeviceToken::class,
            ResolveTenant::class,
            RequireTenant::class,
            ThrottleRequests::class,
            SubstituteBindings::class,
            TrackDevice::class,
            Authorize::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->dontReport([DomainException::class]);

        $exceptions->shouldRenderJsonWhen(static fn (Request $request): bool => $request->is('api/*') || $request->expectsJson());

        $exceptions->render(static function (DomainException $e, Request $request) {
            return response()->json(array_filter([
                'message' => $e->getMessage(),
                'code' => $e->errorCode(),
                'context' => $e->context() !== [] ? $e->context() : null,
            ], static fn ($v): bool => $v !== null), $e->status());
        });

        $exceptions->render(static function (ValidationException $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            return response()->json([
                'message' => $e->getMessage(),
                'code' => 'VALIDATION_FAILED',
                'errors' => $e->errors(),
            ], $e->status);
        });

        $exceptions->render(static function (AuthenticationException $e, Request $request) {
            return response()->json(['message' => $e->getMessage() ?: 'Unauthenticated.', 'code' => 'UNAUTHENTICATED'], 401);
        });

        $exceptions->render(static function (AccessDeniedHttpException|AuthorizationException $e, Request $request) {
            return response()->json(['message' => 'You do not have permission to perform this action.', 'code' => 'FORBIDDEN'], 403);
        });

        $exceptions->render(static function (NotFoundHttpException|ModelNotFoundException $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            return response()->json(['message' => 'The requested resource was not found.', 'code' => 'NOT_FOUND'], 404);
        });

        $exceptions->render(static function (ThrottleRequestsException $e, Request $request) {
            if ($request->is('api/*/auth/login', 'api/*/auth/token')) {
                app(AuthEvents::class)->signInThrottled($request, (int) ($e->getHeaders()['Retry-After'] ?? 60));
            }

            return response()->json([
                'message' => 'Too many requests. Please slow down.',
                'code' => 'TOO_MANY_REQUESTS',
                'retry_after' => (int) ($e->getHeaders()['Retry-After'] ?? 60),
            ], 429, $e->getHeaders());
        });

        $exceptions->render(static function (TokenMismatchException $e, Request $request) {
            return response()->json(['message' => 'Your session has expired. Please reload the page.', 'code' => 'CSRF_TOKEN_MISMATCH'], 419);
        });

        $exceptions->render(static function (HttpExceptionInterface $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            return response()->json([
                'message' => $e->getMessage() !== '' ? $e->getMessage() : 'Request failed.',
                'code' => 'HTTP_'.$e->getStatusCode(),
            ], $e->getStatusCode(), $e->getHeaders());
        });
    })->create();
