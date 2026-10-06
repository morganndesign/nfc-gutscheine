<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\Admin\ApiTokenController as AdminApiTokenController;
use App\Http\Controllers\Api\V1\Admin\CardBatchController as AdminCardBatchController;
use App\Http\Controllers\Api\V1\Admin\CardOrderController as AdminCardOrderController;
use App\Http\Controllers\Api\V1\Admin\CardStationController;
use App\Http\Controllers\Api\V1\Admin\PlatformController;
use App\Http\Controllers\Api\V1\Admin\RestaurantController;
use App\Http\Controllers\Api\V1\Admin\SecurityAlertController;
use App\Http\Controllers\Api\V1\ApiTokenController;
use App\Http\Controllers\Api\V1\AppConfigController;
use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CardController;
use App\Http\Controllers\Api\V1\CardOrderController;
use App\Http\Controllers\Api\V1\CustomerController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\LogoController;
use App\Http\Controllers\Api\V1\NotificationTemplateController;
use App\Http\Controllers\Api\V1\OnlineShopController;
use App\Http\Controllers\Api\V1\PasswordController;
use App\Http\Controllers\Api\V1\PresentmentController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\RoleController;
use App\Http\Controllers\Api\V1\SettingsController;
use App\Http\Controllers\Api\V1\ShopController;
use App\Http\Controllers\Api\V1\StripeWebhookController;
use App\Http\Controllers\Api\V1\TransactionController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\VoucherActionController;
use App\Http\Controllers\Api\V1\VoucherController;
use App\Http\Controllers\OperationsHealthController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| GiftCard Pro REST API — v1
|--------------------------------------------------------------------------
| Authentication: Sanctum SPA cookies (dashboard / web waiter mode, CSRF protected),
| device-bound Bearer tokens (native waiter app, POST auth/token) or Bearer API tokens
| (POS integrations). Tokens are restricted by their abilities.
| Authorization: permission gates ("can:<permission>") + automatic tenant scoping.
*/

Route::prefix('v1')->group(function (): void {
    // ---------------------------------------------------------------- public
    Route::get('app/config', AppConfigController::class)->middleware('throttle:app-config');
    // For the external uptime monitor: database, scheduler and queue worker alive (200 ok / 503 degraded).
    Route::get('health/operations', OperationsHealthController::class)->middleware('throttle:app-config');

    // Online sales, public (decision 2026-10-06): a restaurant's shop, the buyer's order and its status, and the
    // payment provider's signed events. No sign-in.
    Route::prefix('shop')->controller(ShopController::class)->group(function (): void {
        Route::get('orders/{order}', 'status')->middleware('throttle:shop');
        Route::get('{slug}', 'show')->where('slug', '[a-z0-9-]{1,80}')->middleware('throttle:shop');
        Route::get('{slug}/logo', 'logo')->where('slug', '[a-z0-9-]{1,80}')->middleware('throttle:shop');
        Route::post('{slug}/orders', 'order')->where('slug', '[a-z0-9-]{1,80}')->middleware('throttle:online-order');
    });
    Route::post('webhooks/stripe', StripeWebhookController::class)->middleware('throttle:webhook');

    Route::prefix('auth')->group(function (): void {
        Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');
        Route::post('login/code', [AuthController::class, 'confirmCode'])->middleware('throttle:login-code');
        Route::post('login/code/resend', [AuthController::class, 'resendCode'])->middleware('throttle:login-code');
        Route::post('token', [AuthController::class, 'token'])->middleware('throttle:login');
        Route::post('token/code', [AuthController::class, 'confirmTokenCode'])->middleware('throttle:login-code');
        Route::post('token/code/resend', [AuthController::class, 'resendTokenCode'])->middleware('throttle:login-code');
        Route::post('forgot-password', [PasswordController::class, 'forgot'])->middleware('throttle:password-reset');
        Route::post('reset-password', [PasswordController::class, 'reset'])->middleware('throttle:password-reset');
    });

    // ---------------------------------------------------------- authenticated
    Route::middleware(['auth:sanctum', 'remembered', 'device.token', 'tenant', 'throttle:api'])->group(function (): void {
        Route::prefix('auth')->group(function (): void {
            Route::get('me', [AuthController::class, 'me']);
            Route::post('logout', [AuthController::class, 'logout']);
            // Every other sign-in of this person ends: browsers, app phones and tokens (audit S6).
            Route::post('logout-everywhere', [AuthController::class, 'logoutEverywhere'])->middleware('throttle:5,1,logout-everywhere');
            Route::put('profile', [PasswordController::class, 'updateProfile']);
            Route::put('language', [AuthController::class, 'language']);
            // The current-password check must not become a guessing oracle for a stolen session (prefix: own bucket).
            Route::put('password', [PasswordController::class, 'change'])->middleware('throttle:5,1,password-change');
        });

        // --------------------------------------------- restaurant-scoped API
        Route::middleware(['tenant.required', 'device'])->group(function (): void {
            Route::middleware('can:dashboard.view')->prefix('dashboard')->group(function (): void {
                Route::get('stats', [DashboardController::class, 'stats']);
                Route::get('charts', [DashboardController::class, 'charts']);
                Route::get('activity', [DashboardController::class, 'activity']);
            });

            // Proof that a voucher's medium is here, now: single use, 60 seconds (architecture §10.1).
            Route::post('presentments', [PresentmentController::class, 'store'])
                ->middleware(['can:vouchers.redeem', 'throttle:presentment']);
            // A physical card: live authentication relayed by the phone, two steps (architecture §10.2).
            Route::post('presentments/cards', [PresentmentController::class, 'beginCard'])->middleware('throttle:presentment');
            Route::post('presentments/cards/{authentication}', [PresentmentController::class, 'completeCard'])
                ->where('authentication', '[0-9A-HJKMNP-TV-Z]{26}')
                ->middleware('throttle:presentment');

            // Full CSV exports are the most expensive reads: 10 a minute per person, all exports together.
            Route::get('vouchers/export', [VoucherController::class, 'export'])->middleware(['can:vouchers.export', 'throttle:10,1,exports']);
            Route::get('vouchers', [VoucherController::class, 'index'])->middleware('can:vouchers.view');
            Route::post('vouchers', [VoucherController::class, 'store'])->middleware(['can:vouchers.sell', 'idempotent', 'throttle:voucher-operation']);
            Route::get('vouchers/{voucher}', [VoucherController::class, 'show'])->middleware('can:vouchers.view');
            Route::patch('vouchers/{voucher}', [VoucherController::class, 'update'])->middleware('can:vouchers.update');

            Route::prefix('vouchers/{voucher}')->controller(VoucherActionController::class)->group(function (): void {
                Route::middleware(['idempotent', 'throttle:voucher-operation'])->group(function (): void {
                    Route::post('redemptions', 'redeem')->middleware('can:vouchers.redeem');
                    Route::post('reloads', 'reload')->middleware('can:vouchers.reload');
                    Route::post('refund', 'refund')->middleware('can:vouchers.refund');
                    Route::post('cancellation', 'cancelSale')->middleware('can:vouchers.cancel_sale');
                });
                // Same alphabet as the Idempotency-Key header (RequireIdempotencyKey).
                Route::get('redemptions/{idempotencyKey}', 'redemptionOutcome')
                    ->where('idempotencyKey', '[A-Za-z0-9\-_.]{8,96}')
                    ->middleware(['can:vouchers.redeem', 'throttle:redemption-outcome']);
                Route::post('printable', 'reissue')->middleware(['can:vouchers.reissue', 'throttle:voucher-operation']);
                Route::post('card-pickup', 'pickUpCard')->middleware(['can:cards.bind', 'throttle:voucher-operation']);
                Route::post('block', 'block')->middleware('can:vouchers.block');
                Route::post('unblock', 'unblock')->middleware('can:vouchers.unblock');
                Route::post('expire', 'expire')->middleware('can:vouchers.expire');
                Route::post('reinstate', 'reinstate')->middleware('can:vouchers.reinstate');
                Route::get('history', 'history')->middleware('can:vouchers.view');
            });

            // Physical cards (architecture §11), addressed by inventory number.
            Route::get('cards', [CardController::class, 'index'])->middleware('can:cards.view');
            Route::get('cards/{card}', [CardController::class, 'show'])->where('card', 'B-[0-9]{4}-[0-9]{4}-[0-9]{4,}')->middleware('can:cards.view');
            Route::prefix('cards/{card}')->where(['card' => 'B-[0-9]{4}-[0-9]{4}-[0-9]{4,}'])->middleware(['can:cards.manage', 'throttle:voucher-operation'])->group(function (): void {
                Route::post('suspend', [CardController::class, 'suspend']);
                Route::post('resume', [CardController::class, 'resume']);
                Route::post('revoke', [CardController::class, 'revoke']);
                // The platform's test restaurant only; refused for every other restaurant.
                Route::post('test-reset', [CardController::class, 'resetTest']);
                Route::post('replacement', [CardController::class, 'replace'])->middleware('can:cards.bind');
            });
            Route::get('card-batches', [CardController::class, 'batches'])->middleware('can:cards.view');
            Route::post('card-batches/{batch}/receipt', [CardController::class, 'receive'])->whereUuid('batch')->middleware(['can:cards.receive', 'throttle:voucher-operation']);
            // Ordering cards from the platform: whoever confirms deliveries (managers, owners).
            // Online shop (owners) and its orders.
            Route::prefix('online-shop')->controller(OnlineShopController::class)->middleware('can:settings.manage')->group(function (): void {
                Route::get('/', 'show');
                Route::put('/', 'update');
                Route::post('connect', 'connect')->middleware('throttle:10,1,online-connect');
                Route::post('refresh', 'refresh')->middleware('throttle:20,1,online-refresh');
                Route::delete('connection', 'disconnect');
            });
            Route::get('online-orders', [OnlineShopController::class, 'orders'])->middleware('can:vouchers.view');

            Route::get('card-orders', [CardOrderController::class, 'index'])->middleware('can:cards.view');
            Route::post('card-orders', [CardOrderController::class, 'store'])->middleware(['can:cards.receive', 'throttle:voucher-operation', 'idempotent:optional']);

            Route::get('transactions/export', [TransactionController::class, 'export'])->middleware(['can:transactions.export', 'throttle:10,1,exports']);
            Route::get('reports/cash-up', [ReportController::class, 'cashUp'])->middleware('can:transactions.view');
            Route::get('reports/payments/export', [ReportController::class, 'paymentsExport'])->middleware(['can:transactions.export', 'throttle:10,1,exports']);
            Route::get('transactions', [TransactionController::class, 'index'])->middleware('can:transactions.view');
            Route::get('transactions/{transaction}', [TransactionController::class, 'show'])->middleware('can:transactions.view');
            Route::post('transactions/{transaction}/reverse', [TransactionController::class, 'reverse'])->middleware('can:transactions.reverse');

            Route::get('customers', [CustomerController::class, 'index'])->middleware('can:customers.view');
            Route::post('customers', [CustomerController::class, 'store'])->middleware('can:customers.manage');
            Route::get('customers/{customer}', [CustomerController::class, 'show'])->middleware('can:customers.view');
            Route::patch('customers/{customer}', [CustomerController::class, 'update'])->middleware('can:customers.manage');
            Route::post('customers/{customer}/anonymize', [CustomerController::class, 'anonymize'])->middleware('can:customers.manage');

            Route::get('roles', [RoleController::class, 'index'])->middleware('can:users.view');
            Route::get('users', [UserController::class, 'index'])->middleware('can:users.view');
            Route::post('users', [UserController::class, 'store'])->middleware('can:users.manage');
            Route::get('users/{user}', [UserController::class, 'show'])->middleware('can:users.view');
            Route::patch('users/{user}', [UserController::class, 'update'])->middleware('can:users.manage');
            Route::put('users/{user}/loyalty', [UserController::class, 'loyalty'])->middleware('can:users.manage');
            Route::post('users/{user}/deactivate', [UserController::class, 'deactivate'])->middleware('can:users.manage');
            Route::post('users/{user}/activate', [UserController::class, 'activate'])->middleware('can:users.manage');
            Route::post('users/{user}/password-reset', [UserController::class, 'sendPasswordReset'])->middleware('can:users.manage');

            Route::get('restaurant/logo', [LogoController::class, 'show']);
            Route::get('devices/current', [DeviceController::class, 'current']);
            Route::get('devices', [DeviceController::class, 'index'])->middleware('can:devices.view');
            Route::patch('devices/{device}', [DeviceController::class, 'update'])->middleware('can:devices.manage');
            Route::post('devices/{device}/revoke', [DeviceController::class, 'revoke'])->middleware('can:devices.manage');
            Route::post('devices/{device}/restore', [DeviceController::class, 'restore'])->middleware('can:devices.manage');

            Route::middleware('can:settings.manage')->prefix('settings')->group(function (): void {
                Route::get('/', [SettingsController::class, 'show']);
                Route::put('restaurant', [SettingsController::class, 'updateRestaurant']);
                Route::put('vouchers', [SettingsController::class, 'updateVoucherSettings']);
                // Decoding and re-encoding an image is expensive.
                Route::post('logo', [LogoController::class, 'store'])->middleware('throttle:10,1,logo');
                Route::delete('logo', [LogoController::class, 'destroy']);
                Route::get('notification-templates', [NotificationTemplateController::class, 'index']);
                Route::put('notification-templates/{key}', [NotificationTemplateController::class, 'update'])->where('key', '[a-z_]+');
            });

            Route::middleware('can:api_tokens.manage')->group(function (): void {
                Route::get('api-tokens', [ApiTokenController::class, 'index']);
                Route::post('api-tokens', [ApiTokenController::class, 'store']);
                Route::post('api-tokens/{token}/revoke', [ApiTokenController::class, 'revoke'])->whereUuid('token');
            });

            Route::get('audit-logs', [AuditLogController::class, 'index'])->middleware('can:audit.view');
        });

        // ------------------------------------------------------ platform admin
        Route::prefix('admin')->middleware('can:platform.restaurants.manage')->group(function (): void {
            Route::get('stats', [PlatformController::class, 'stats']);
            Route::get('restaurants', [RestaurantController::class, 'index']);
            Route::post('restaurants', [RestaurantController::class, 'store']);
            // Archived (soft-deleted) restaurants can only be viewed, restored or deleted.
            Route::get('restaurants/{restaurant}', [RestaurantController::class, 'show'])->withTrashed();
            Route::patch('restaurants/{restaurant}', [RestaurantController::class, 'update']);
            Route::post('restaurants/{restaurant}/suspend', [RestaurantController::class, 'suspend']);
            Route::post('restaurants/{restaurant}/reactivate', [RestaurantController::class, 'reactivate']);
            Route::post('restaurants/{restaurant}/archive', [RestaurantController::class, 'archive']);
            Route::post('restaurants/{restaurant}/restore', [RestaurantController::class, 'restore'])->withTrashed();
            Route::delete('restaurants/{restaurant}', [RestaurantController::class, 'destroy'])->withTrashed();
            Route::post('restaurants/{restaurant}/invitation', [RestaurantController::class, 'resendOwnerInvitation']);
            Route::post('restaurants/{restaurant}/owners', [RestaurantController::class, 'inviteOwner']);
            Route::post('restaurants/{restaurant}/users/{user}/invitation', [RestaurantController::class, 'resendUserInvitation']);
            Route::get('audit-logs', [PlatformController::class, 'auditLogs'])->middleware('can:platform.audit.view');
            Route::get('security-alerts', [SecurityAlertController::class, 'index'])->middleware('can:platform.audit.view');
            Route::post('security-alerts/{alert}/acknowledge', [SecurityAlertController::class, 'acknowledge'])
                ->where('alert', '[0-9a-hjkmnp-tv-zA-HJKMNP-TV-Z]{26}')->middleware('can:platform.audit.view');
            // Incident response: list and revoke any restaurant's access tokens (audit S2).
            Route::get('api-tokens', [AdminApiTokenController::class, 'index']);
            Route::post('api-tokens/{token}/revoke', [AdminApiTokenController::class, 'revoke'])->whereUuid('token');
            Route::get('system-settings', [PlatformController::class, 'settings'])->middleware('can:platform.settings.manage');
            Route::put('system-settings', [PlatformController::class, 'updateSettings'])->middleware('can:platform.settings.manage');
            Route::get('mail', [PlatformController::class, 'mailStatus'])->middleware('can:platform.settings.manage');
            Route::post('mail/test', [PlatformController::class, 'sendTestMail'])->middleware('can:platform.settings.manage');
        });

        // ------------------------------------------------------ card batches (platform)
        Route::prefix('admin/card-batches')->middleware('can:platform.cards.manage')->controller(AdminCardBatchController::class)->group(function (): void {
            Route::get('/', 'index');
            Route::post('/', 'store');
            Route::get('{batch}', 'show')->whereUuid('batch');
            Route::post('{batch}/status', 'status')->whereUuid('batch');
            Route::post('{batch}/release', 'release')->whereUuid('batch');
            Route::post('{batch}/shipment', 'ship')->whereUuid('batch');
            Route::post('{batch}/hold-resolution', 'resolveHold')->whereUuid('batch');
        });

        // ------------------------------------------------------ card orders of the restaurants (platform)
        Route::prefix('admin/card-orders')->middleware('can:platform.cards.manage')->controller(AdminCardOrderController::class)->group(function (): void {
            Route::get('/', 'index');
            Route::post('{order}/accept', 'accept')->whereUuid('order');
            Route::post('{order}/decline', 'decline')->whereUuid('order');
        });

        // ------------------------------------------------------ personalisation station (internal)
        Route::prefix('admin')->middleware(['can:platform.cards.personalize', 'throttle:presentment'])->group(function (): void {
            Route::get('station/batches', [CardStationController::class, 'batches']);
            Route::post('card-batches/{batch}/personalizations', [CardStationController::class, 'begin'])->whereUuid('batch');
            Route::post('personalizations/{personalization}', [CardStationController::class, 'continue'])
                ->where('personalization', '[0-9A-HJKMNP-TV-Z]{26}');
        });
    });
});
