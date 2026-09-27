<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Validates the Idempotency-Key header (client-generated, e.g. a UUID per attempt) so network
 * retries or double taps can never book twice.
 *
 * Usage: `idempotent` (header required — money movements) or `idempotent:optional`.
 * The ":" character is reserved for keys derived by the server (e.g. "<key>:in" for transfers).
 */
final class RequireIdempotencyKey
{
    public const ATTRIBUTE = 'idempotency_key';

    public function handle(Request $request, Closure $next, string $mode = 'required'): Response
    {
        $key = $request->header('Idempotency-Key');
        $max = (int) config('giftcard.security.idempotency_key_max_length', 96);

        if ($key === null && $mode === 'optional') {
            return $next($request);
        }

        if (! is_string($key) || preg_match('/^[A-Za-z0-9\-_.]{8,'.$max.'}$/', $key) !== 1) {
            return response()->json([
                'message' => 'A valid Idempotency-Key header is required for this operation.',
                'code' => 'IDEMPOTENCY_KEY_REQUIRED',
            ], 400);
        }

        $request->attributes->set(self::ATTRIBUTE, $key);

        return $next($request);
    }
}
