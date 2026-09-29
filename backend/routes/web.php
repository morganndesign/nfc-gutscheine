<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Route;

// The API server has no HTML pages; the frontend is served by the Next.js application. Password-reset and
// invitation links point at the frontend directly, with the token in the URL fragment.
Route::get('/', static fn () => response()->json(['name' => config('app.name'), 'api' => url('/api/v1')]));
