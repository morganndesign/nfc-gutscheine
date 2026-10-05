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
 * Sign-in in two steps: password, then a 6-digit code sent by e-mail. Dashboard (decision 2026-10-05): a browser
 * that confirmed a code is trusted for 15 days (an encrypted, HTTP-only cookie holding a secret whose hash is
 * stored). Waiter app (decision 2026-10-06): every sign-in, bound to the phone that asked; the token then lasts
 * until the app is updated (EnforceDeviceToken).
 *
 * Only keyed hashes of codes and secrets are stored; a code is single use, expires after 10 minutes and dies after
 * 5 wrong tries; 15 wrong codes of one person within an hour lock the account. A new password or "sign out
 * everywhere" forgets every trusted browser.
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

    /**
     * After the password: a new code by e-mail. Earlier open codes of this user die. `$deviceId` = an app sign-in
     * from that phone; null = the dashboard.
     */
    public function start(User $user, bool $remember, ?string $deviceId = null): LoginCode
    {
        $code = self::newCode();
        $login = DB::transaction(function () use ($user, $remember, $code, $deviceId): LoginCode {
            LoginCode::query()->where('user_id', $user->getKey())->whereNull('used_at')->update(['used_at' => Carbon::now()]);
            $login = new LoginCode;
            $login->forceFill([
                'user_id' => $user->getKey(),
                'client' => $deviceId === null ? 'web' : 'app',
                'device_id' => $deviceId,
                'remember' => $remember,
                'sent_at' => Carbon::now(),
                'expires_at' => Carbon::now()->addMinutes((int) config('giftcard.security.login_code_minutes')),
                'code_hash' => '',
            ])->save();
            $login->forceFill(['code_hash' => self::codeHash($login, $code)])->save();

            return $login;
        });
        $this->send($user, $code, $login->client);

        return $login;
    }

    /** "Send a new code": same sign-in, new code, not more often than every 30 seconds and at most 4 times. */
    public function resend(string $id): LoginCode
    {
        $login = $this->open($id);
        $wait = (int) config('giftcard.security.login_code_resend_seconds') - (int) $login->sent_at->diffInSeconds(Carbon::now(), true);
        if ($wait > 0) {
            throw ValidationException::withMessages(['code' => __('api.login_code_wait', ['seconds' => $wait])])->errorBag('wait');
        }
        if ($login->sends >= (int) config('giftcard.security.login_code_sends')) {
            $login->forceFill(['used_at' => Carbon::now()])->save();
            throw ValidationException::withMessages(['code' => __('api.login_code_expired')])->errorBag('expired');
        }

        $code = self::newCode();
        $login->forceFill([
            'code_hash' => self::codeHash($login, $code),
            'sends' => $login->sends + 1,
            'sent_at' => Carbon::now(),
            'expires_at' => Carbon::now()->addMinutes((int) config('giftcard.security.login_code_minutes')),
        ])->save();
        $this->send($login->user, $code, $login->client);

        return $login;
    }

    /**
     * The code from the e-mail: the user, once, on the client (and for the app the phone) that asked for it. A wrong
     * code counts; the 5th wrong one ends this sign-in, the 15th of this person within an hour locks the account.
     */
    public function confirm(Request $request, string $id, string $code, string $client = 'web', ?string $deviceId = null): LoginCode
    {
        // The wrong try is committed before the refusal is thrown (an exception inside the transaction would
        // roll the count back and allow unlimited guesses).
        [$login, $outcome] = DB::transaction(function () use ($id, $code, $client, $deviceId): array {
            $login = $this->open($id, lock: true);
            if ($login->client !== $client || ($client === 'app' && $login->device_id !== $deviceId)) {
                throw ValidationException::withMessages(['code' => __('api.login_code_expired')])->errorBag('expired');
            }
            if (hash_equals($login->code_hash, self::codeHash($login, $code))) {
                $login->forceFill(['used_at' => Carbon::now()])->save();

                return [$login, 'ok'];
            }

            $attempts = $login->attempts + 1;
            $dead = $attempts >= (int) config('giftcard.security.login_code_attempts');
            $login->forceFill(['attempts' => $attempts] + ($dead ? ['used_at' => Carbon::now()] : []))->save();

            $wrongThisHour = (int) LoginCode::query()->where('user_id', $login->user_id)->where('created_at', '>=', Carbon::now()->subHour())->sum('attempts');
            if ($wrongThisHour >= (int) config('giftcard.security.login_code_hourly_attempts')) {
                $login->user->forceFill(['locked_until' => Carbon::now()->addMinutes((int) config('giftcard.security.login_code_lock_minutes'))])->save();
                LoginCode::query()->where('user_id', $login->user_id)->whereNull('used_at')->update(['used_at' => Carbon::now()]);

                return [$login, 'locked'];
            }

            return [$login, $dead ? 'dead' : 'wrong'];
        });
        if ($outcome === 'ok') {
            return $login;
        }

        $reason = match ($outcome) {
            'locked' => 'code_lockout',
            'dead' => 'code_attempts_exceeded',
            default => 'wrong_code',
        };
        $this->authEvents->signInRefused($request, $login->user->email, $login->user, $reason, $client, $login->attempts);

        throw ValidationException::withMessages(['code' => __(match ($outcome) {
            'locked' => 'api.login_code_locked',
            'dead' => 'api.login_code_expired',
            default => 'api.login_code_wrong',
        })])->errorBag(match ($outcome) {
            'locked' => 'locked',
            'dead' => 'expired',
            default => 'wrong',
        });
    }

    /**
     * Emergency path when e-mail is down (`php artisan auth:login-code`): a fresh code for this person's open
     * sign-in, shown to whoever runs the command on the server instead of e-mailed. Recorded in the audit log.
     */
    public function codeForConsole(User $user): string
    {
        /** @var LoginCode|null $login */
        $login = LoginCode::query()->where('user_id', $user->getKey())->whereNull('used_at')->where('expires_at', '>', Carbon::now())->latest('created_at')->first();
        if ($login === null) {
            throw new \RuntimeException('No open sign-in for this person: sign in with the password first, then run this command within 10 minutes.');
        }
        $code = self::newCode();
        $login->forceFill(['code_hash' => self::codeHash($login, $code), 'sent_at' => Carbon::now()])->save();

        return $code;
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
            throw ValidationException::withMessages(['code' => __('api.login_code_expired')])->errorBag('expired');
        }

        return $login;
    }

    private function send(User $user, string $code, string $client): void
    {
        $language = in_array($user->locale, ['de', 'en', 'bs'], true) ? $user->locale : (string) config('giftcard.mail_locale');
        try {
            $user->notify((new LoginCodeNotification($code, app: $client === 'app'))->locale($language));
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
