<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Route;

// The API server has no HTML pages; the frontend is served by the Next.js application.
Route::get('/', static fn () => response()->json(['name' => config('app.name'), 'api' => url('/api/v1')]));

// Laravel's password broker builds reset links through this named route; it redirects to the frontend.
Route::get('/reset-password/{token}', static fn (string $token) => redirect()->away(
    config('giftcard.frontend_url').'/reset-password?token='.urlencode($token).'&email='.urlencode((string) request('email')),
))->name('password.reset');
