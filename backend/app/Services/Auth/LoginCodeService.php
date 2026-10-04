<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Models\LoginCode;
use App\Models\TrustedBrowser;
use App\Models\User;
use App\Notifications\LoginCodeNotification;
use App\Services\Security\AuthEvents;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Cookie;
use Throwable;

/**
 * Dashboard sign-in in two steps (decision 2026-10-05): password, then a 6-digit code sent by e-mail. A browser
 * that confirmed a code is trusted for 15 days (an encrypted, HTTP-only cookie holding a secret whose hash is
 * stored). The waiter app signs in with device-bound tokens and is not affected.
 *
 * Only keyed hashes of codes and secrets are stored; a code is single use, expires after 10 minutes and dies after
 * 5 wrong tries. A new password or "sign out everywhere" forgets every trusted browser.
 */
final class LoginCodeService
{
    public const COOKIE = 'gcp_trusted_browser';

    public function __construct(private readonly AuthEvents $authEvents) {}

    /** Whether this browser confirmed a code for this user within the last 15 days. */
    public function isTrusted(Request $request, User $user): bool
    {
        $value = $request->cookie(self::COOKIE);
        if (! is_string($value) || ! str_contains($value, '|')) {
            return false;
        }
        [$id, $secret] = explode('|', $value, 2);
        if (! Str::isUuid($id)) {
            return false;
        }

        /** @var TrustedBrowser|null $browser */
        $browser = TrustedBrowser::query()->whereKey($id)->where('user_id', $user->getKey())->where('expires_at', '>', Carbon::now())->first();
        if ($browser === null || ! hash_equals($browser->secret_hash, self::hash($secret))) {
            return false;
        }
        $browser->forceFill(['last_used_at' => Carbon::now()])->save();

        return true;
    }

    /** After the password: a new code by e-mail. Earlier open codes of this user die. */
    public function start(User $user, bool $remember): LoginCode
    {
        $code = self::newCode();
        $login = DB::transaction(function () use ($user, $remember, $code): LoginCode {
            LoginCode::query()->where('user_id', $user->getKey())->whereNull('used_at')->update(['used_at' => Carbon::now()]);
            $login = new LoginCode;
            $login->forceFill([
                'user_id' => $user->getKey(),
                'remember' => $remember,
                'sent_at' => Carbon::now(),
                'expires_at' => Carbon::now()->addMinutes((int) config('giftcard.security.login_code_minutes')),
                'code_hash' => '',
            ])->save();
            $login->forceFill(['code_hash' => self::codeHash($login, $code)])->save();

            return $login;
        });
        $this->send($user, $code);

        return $login;
    }

    /** "Send a new code": same sign-in, new code, not more often than every 30 seconds and at most 4 times. */
    public function resend(string $id): LoginCode
    {
        $login = $this->open($id);
        $wait = (int) config('giftcard.security.login_code_resend_seconds') - (int) $login->sent_at->diffInSeconds(Carbon::now(), true);
        if ($wait > 0) {
            throw ValidationException::withMessages(['code' => __('api.login_code_wait', ['seconds' => $wait])]);
        }
        if ($login->sends >= (int) config('giftcard.security.login_code_sends')) {
            $login->forceFill(['used_at' => Carbon::now()])->save();
            throw ValidationException::withMessages(['code' => __('api.login_code_expired')]);
        }

        $code = self::newCode();
        $login->forceFill([
            'code_hash' => self::codeHash($login, $code),
            'sends' => $login->sends + 1,
            'sent_at' => Carbon::now(),
            'expires_at' => Carbon::now()->addMinutes((int) config('giftcard.security.login_code_minutes')),
        ])->save();
        $this->send($login->user, $code);

        return $login;
    }

    /** The code from the e-mail: the user, once. A wrong code counts; the 5th wrong one ends this sign-in. */
    public function confirm(Request $request, string $id, string $code): LoginCode
    {
        // The wrong try is committed before the refusal is thrown (an exception inside the transaction would
        // roll the count back and allow unlimited guesses).
        [$login, $outcome] = DB::transaction(function () use ($id, $code): array {
            $login = $this->open($id, lock: true);
            if (hash_equals($login->code_hash, self::codeHash($login, $code))) {
                $login->forceFill(['used_at' => Carbon::now()])->save();

                return [$login, 'ok'];
            }

            $attempts = $login->attempts + 1;
            $dead = $attempts >= (int) config('giftcard.security.login_code_attempts');
            $login->forceFill(['attempts' => $attempts] + ($dead ? ['used_at' => Carbon::now()] : []))->save();

            return [$login, $dead ? 'dead' : 'wrong'];
        });
        if ($outcome === 'ok') {
            return $login;
        }

        $this->authEvents->signInRefused($request, $login->user->email, $login->user, $outcome === 'dead' ? 'code_attempts_exceeded' : 'wrong_code', 'web', $login->attempts);

        throw ValidationException::withMessages(['code' => __($outcome === 'dead' ? 'api.login_code_expired' : 'api.login_code_wrong')]);
    }

    /** Trust this browser for 15 days: the cookie to send with the signed-in answer. */
    public function trust(Request $request, User $user): Cookie
    {
        $secret = Str::random(48);
        $days = (int) config('giftcard.security.trusted_browser_days');
        $browser = new TrustedBrowser;
        $browser->forceFill([
            'user_id' => $user->getKey(),
            'secret_hash' => self::hash($secret),
            'user_agent' => mb_substr((string) $request->userAgent(), 0, 500),
            'expires_at' => Carbon::now()->addDays($days),
            'last_used_at' => Carbon::now(),
        ])->save();
        // One user, a few browsers: keep the table small.
        TrustedBrowser::query()->where('user_id', $user->getKey())->where('expires_at', '<=', Carbon::now())->delete();

        return cookie(self::COOKIE, $browser->id.'|'.$secret, $days * 24 * 60, '/', config('session.domain'), config('session.secure'), true, false, 'lax');
    }

    /** A new password, a reset or "sign out everywhere": no browser is trusted any more. */
    public function forget(User $user): void
    {
        TrustedBrowser::query()->where('user_id', $user->getKey())->delete();
        LoginCode::query()->where('user_id', $user->getKey())->whereNull('used_at')->update(['used_at' => Carbon::now()]);
    }

    /** "m•••@gmail.com": enough to recognise the mailbox, not enough to learn the address. */
    public static function maskEmail(string $email): string
    {
        [$local, $domain] = array_pad(explode('@', $email, 2), 2, '');

        return mb_substr($local, 0, 1).'•••@'.$domain;
    }

    private function open(string $id, bool $lock = false): LoginCode
    {
        $login = Str::isUuid($id) ? LoginCode::query()->whereKey($id)->when($lock, static fn ($q) => $q->lockForUpdate())->first() : null;
        if ($login === null || $login->used_at !== null || $login->expires_at->isPast() || ! $login->user->isActive()) {
            throw ValidationException::withMessages(['code' => __('api.login_code_expired')]);
        }

        return $login;
    }

    private function send(User $user, string $code): void
    {
        $language = in_array($user->locale, ['de', 'en', 'bs'], true) ? $user->locale : (string) config('giftcard.mail_locale');
        try {
            $user->notify((new LoginCodeNotification($code))->locale($language));
        } catch (Throwable $e) {
            Log::warning('Sign-in code could not be sent.', ['user_id' => $user->getKey(), 'error' => $e->getMessage()]);
            throw ValidationException::withMessages(['email' => __('api.login_code_unsent')]);
        }
    }

    private static function newCode(): string
    {
        return str_pad((string) random_int(0, 999_999), 6, '0', STR_PAD_LEFT);
    }

    private static function codeHash(LoginCode $login, string $code): string
    {
        return hash_hmac('sha256', $login->getKey().'|'.preg_replace('/\D/', '', $code), (string) config('app.key'));
    }

    private static function hash(string $secret): string
    {
        return hash_hmac('sha256', $secret, (string) config('app.key'));
    }
}
