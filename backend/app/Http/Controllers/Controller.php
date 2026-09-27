<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\Tenancy\TenantContext;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

abstract class Controller
{
    use AuthorizesRequests;

    protected function tenant(): TenantContext
    {
        return app(TenantContext::class);
    }

    protected function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }

    /** Start of a calendar day (Y-m-d) in the restaurant's timezone, as UTC for querying. */
    protected function dayStart(string $date): Carbon
    {
        return Carbon::parse($date, $this->timezone())->startOfDay()->utc();
    }

    /** End of a calendar day (Y-m-d) in the restaurant's timezone, as UTC for querying. */
    protected function dayEnd(string $date): Carbon
    {
        return Carbon::parse($date, $this->timezone())->endOfDay()->utc();
    }

    protected function timezone(): string
    {
        return $this->tenant()->restaurant()->timezone ?? (string) config('app.timezone');
    }

    protected function perPage(Request $request, int $default = 25): int
    {
        return max(1, min(100, (int) $request->integer('per_page', $default)));
    }
}
