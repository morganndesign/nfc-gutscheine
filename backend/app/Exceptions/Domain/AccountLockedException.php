<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

use Illuminate\Http\JsonResponse;

/**
 * Raised after too many failed sign-in attempts. `retry_after` (seconds) is also returned at the top level,
 * where the web app has always read it.
 */
final class AccountLockedException extends DomainException
{
    public function __construct(private readonly int $retryAfter)
    {
        parent::__construct(context: ['retry_after' => $retryAfter]);
    }

    public function errorCode(): string
    {
        return 'ACCOUNT_LOCKED';
    }

    public function status(): int
    {
        return 423;
    }

    public function render(): JsonResponse
    {
        return response()->json([
            'message' => $this->getMessage(),
            'code' => $this->errorCode(),
            'retry_after' => $this->retryAfter,
            'context' => $this->context(),
        ], $this->status(), ['Retry-After' => (string) $this->retryAfter]);
    }

    protected function defaultMessage(): string
    {
        return 'Too many failed login attempts. Please try again later.';
    }
}
