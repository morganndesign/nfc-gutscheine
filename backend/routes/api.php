<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\Admin\PlatformController;
use App\Http\Controllers\Api\V1\Admin\RestaurantController;
use App\Http\Controllers\Api\V1\ApiTokenController;
use App\Http\Controllers\Api\V1\AppConfigController;
use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CustomerController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\NotificationTemplateController;
use App\Http\Controllers\Api\V1\PasswordController;
use App\Http\Controllers\Api\V1\PresentmentController;
use App\Http\Controllers\Api\V1\RoleController;
use App\Http\Controllers\Api\V1\SettingsController;
use App\Http\Controllers\Api\V1\TransactionController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\VoucherActionController;
use App\Http\Controllers\Api\V1\VoucherController;
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

    Route::prefix('auth')->group(function (): void {
        Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');
        Route::post('token', [AuthController::class, 'token'])->middleware('throttle:login');
        Route::post('forgot-password', [PasswordController::class, 'forgot'])->middleware('throttle:password-reset');
        Route::post('reset-password', [PasswordController::class, 'reset'])->middleware('throttle:password-reset');
    });

    // ---------------------------------------------------------- authenticated
    Route::middleware(['auth:sanctum', 'device.token', 'tenant', 'throttle:api'])->group(function (): void {
        Route::prefix('auth')->group(function (): void {
            Route::get('me', [AuthController::class, 'me']);
            Route::post('logout', [AuthController::class, 'logout']);
            Route::put('profile', [PasswordController::class, 'updateProfile']);
            Route::put('password', [PasswordController::class, 'change']);
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

            Route::get('vouchers/export', [VoucherController::class, 'export'])->middleware('can:vouchers.export');
            Route::get('vouchers', [VoucherController::class, 'index'])->middleware('can:vouchers.view');
            Route::post('vouchers', [VoucherController::class, 'store'])->middleware(['can:vouchers.sell', 'idempotent', 'throttle:voucher-operation']);
            Route::get('vouchers/{voucher}', [VoucherController::class, 'show'])->middleware('can:vouchers.view');
            Route::patch('vouchers/{voucher}', [VoucherController::class, 'update'])->middleware('can:vouchers.update');

            Route::prefix('vouchers/{voucher}')->controller(VoucherActionController::class)->group(function (): void {
                Route::middleware(['idempotent', 'throttle:voucher-operation'])->group(function (): void {
                    Route::post('redemptions', 'redeem')->middleware('can:vouchers.redeem');
                    Route::post('reloads', 'reload')->middleware('can:vouchers.reload');
                });
                Route::post('block', 'block')->middleware('can:vouchers.block');
                Route::post('unblock', 'unblock')->middleware('can:vouchers.unblock');
                Route::post('expire', 'expire')->middleware('can:vouchers.expire');
                Route::post('reinstate', 'reinstate')->middleware('can:vouchers.reinstate');
                Route::get('history', 'history')->middleware('can:vouchers.view');
            });

            Route::get('transactions/export', [TransactionController::class, 'export'])->middleware('can:transactions.export');
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
            Route::post('users/{user}/deactivate', [UserController::class, 'deactivate'])->middleware('can:users.manage');
            Route::post('users/{user}/activate', [UserController::class, 'activate'])->middleware('can:users.manage');
            Route::post('users/{user}/password-reset', [UserController::class, 'sendPasswordReset'])->middleware('can:users.manage');

            Route::get('devices/current', [DeviceController::class, 'current']);
            Route::get('devices', [DeviceController::class, 'index'])->middleware('can:devices.view');
            Route::patch('devices/{device}', [DeviceController::class, 'update'])->middleware('can:devices.manage');
            Route::post('devices/{device}/revoke', [DeviceController::class, 'revoke'])->middleware('can:devices.manage');
            Route::post('devices/{device}/restore', [DeviceController::class, 'restore'])->middleware('can:devices.manage');

            Route::middleware('can:settings.manage')->prefix('settings')->group(function (): void {
                Route::get('/', [SettingsController::class, 'show']);
                Route::put('restaurant', [SettingsController::class, 'updateRestaurant']);
                Route::put('vouchers', [SettingsController::class, 'updateVoucherSettings']);
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
            Route::post('restaurants/{restaurant}/users/{user}/invitation', [RestaurantController::class, 'resendUserInvitation']);
            Route::get('audit-logs', [PlatformController::class, 'auditLogs'])->middleware('can:platform.audit.view');
            Route::get('system-settings', [PlatformController::class, 'settings'])->middleware('can:platform.settings.manage');
            Route::put('system-settings', [PlatformController::class, 'updateSettings'])->middleware('can:platform.settings.manage');
            Route::get('mail', [PlatformController::class, 'mailStatus'])->middleware('can:platform.settings.manage');
            Route::post('mail/test', [PlatformController::class, 'sendTestMail'])->middleware('can:platform.settings.manage');
        });
    });
});
