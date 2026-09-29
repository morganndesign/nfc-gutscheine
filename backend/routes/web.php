<?php

declare(strict_types=1);

use App\Http\Controllers\Tap\TapPageController;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\ValidateCsrfToken;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Support\Facades\Route;
use Illuminate\View\Middleware\ShareErrorsFromSession;

// The API server has no HTML pages except the guest tap page below; the frontend is served by the Next.js application. Password-reset and
// invitation links point at the frontend directly, with the token in the URL fragment.
Route::get('/', static fn () => response()->json(['name' => config('app.name'), 'api' => url('/api/v1')]));

// The tap domain (t.giftcardpro.at): a guest taps their card with their own phone and sees the balance. Stateless:
// no session, no cookies. SUN-verified; it can never spend (architecture §10.3).
Route::get('/t/{keySet}', TapPageController::class)
    ->where('keySet', '[a-z0-9][a-z0-9._-]{0,31}')
    ->withoutMiddleware([StartSession::class, ShareErrorsFromSession::class, ValidateCsrfToken::class, AddQueuedCookiesToResponse::class, EncryptCookies::class])
    ->middleware('throttle:tap')
    ->name('tap');
