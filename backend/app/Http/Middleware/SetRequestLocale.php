<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Language of API responses (validation messages, translated status texts): de, en or bs.
 *
 * Signed in → the user's own language (users.locale). Otherwise (login, forgot/reset password) the browser's
 * Accept-Language; hr/sr/sh/cnr are served the Bosnian texts, anything unknown gets German (DACH market).
 * Runs after authentication (see the middleware priority in bootstrap/app.php).
 *
 * E-mails are not affected: each one sets its language explicitly (invitations follow the restaurant, account
 * notices the recipient's users.locale, voucher mails the restaurant's template locale).
 */
final class SetRequestLocale
{
    public const SUPPORTED = ['de', 'en', 'bs'];

    public const DEFAULT = 'de';

    public function handle(Request $request, Closure $next): Response
    {
        app()->setLocale($this->resolve($request));

        return $next($request);
    }

    public function resolve(Request $request): string
    {
        // Only a user the auth middleware already resolved: on guest routes, asking the guard would restore a
        // "remember me" session here, past the device check of BindRememberedSignIn (audit S1).
        $guard = Auth::guard();
        $user = $guard->hasUser() ? $guard->user() : null;
        if ($user instanceof User) {
            $language = self::normalize((string) $user->locale);
            if ($language !== null) {
                return $language;
            }
        }

        // Sorted by q-value, most preferred first.
        foreach ($request->getLanguages() as $tag) {
            $language = self::normalize($tag);
            if ($language !== null) {
                return $language;
            }
        }

        return self::DEFAULT;
    }

    /** "de-AT" → de, "en_GB" → en, "hr-HR" / "sr-Latn" / "bs" → bs; null when not supported. */
    public static function normalize(string $tag): ?string
    {
        $primary = strtolower(explode('-', str_replace('_', '-', trim($tag)))[0]);

        return match ($primary) {
            'de' => 'de',
            'en' => 'en',
            'bs', 'hr', 'sr', 'sh', 'cnr' => 'bs',
            default => null,
        };
    }
}
