<?php

declare(strict_types=1);

namespace App\Services\Users;

use App\Enums\RoleSlug;
use App\Models\NotificationLog;
use App\Models\Restaurant;
use App\Models\SystemSetting;
use App\Models\User;
use App\Notifications\StaffInvitation;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Throwable;

/**
 * Invitations of new accounts (restaurant owners created by the platform, staff created by a restaurant).
 *
 * The account exists from the start but has an unknown random password. The invitation carries a
 * single-use token of the "invitations" password broker (random, stored only as a hash, valid 72 hours;
 * a new invitation replaces the previous token). Choosing a password with it activates the account.
 * Every attempt is recorded in notification_logs, so a failed or undelivered e-mail is visible.
 */
final class InvitationService
{
    public const TEMPLATE_KEY = 'staff_invitation';

    /** Mailers that accept a message without delivering it to the recipient. */
    private const NON_DELIVERING_MAILERS = ['log'];

    public function send(User $user, Restaurant $restaurant, ?string $invitedBy): NotificationLog
    {
        $log = NotificationLog::query()->create([
            'restaurant_id' => $restaurant->getKey(),
            'template_key' => self::TEMPLATE_KEY,
            'channel' => 'mail',
            'recipient' => $user->email,
            'status' => 'pending',
        ]);

        $support = SystemSetting::get('platform.support_email');

        try {
            $token = Password::broker('invitations')->createToken($user);
            $user->notify((new StaffInvitation(
                $token,
                $restaurant->name,
                $invitedBy,
                $user->roleSlug() === RoleSlug::Owner,
                is_string($support) && $support !== '' ? $support : null,
            ))->locale($this->localeFor($restaurant)));

            $log->update($this->mailDelivers()
                ? ['status' => 'sent', 'sent_at' => Carbon::now()]
                : ['status' => 'logged', 'error' => $this->nonDeliveryReason()]);
        } catch (Throwable $e) {
            report($e);
            $log->update(['status' => 'failed', 'error' => mb_substr($e->getMessage(), 0, 1000)]);
        }

        return $log;
    }

    /**
     * Language of the invitation: the restaurant's language when a translation exists (de-AT, de-DE, de-CH → de;
     * en-GB, en-US → en), otherwise the platform default (config giftcard.mail_locale, "de").
     */
    public function localeFor(Restaurant $restaurant): string
    {
        /** @var list<string> $supported */
        $supported = (array) config('giftcard.mail_locales', ['de']);
        $language = Str::before(Str::lower((string) $restaurant->locale), '-');
        if (in_array($language, $supported, true)) {
            return $language;
        }

        $default = (string) config('giftcard.mail_locale', 'de');

        return in_array($default, $supported, true) ? $default : 'de';
    }

    /** False when e-mails are only written to the log (MAIL_MAILER=log): nobody receives an invitation. */
    public function mailDelivers(): bool
    {
        return ! in_array((string) config('mail.default'), self::NON_DELIVERING_MAILERS, true);
    }

    public function nonDeliveryReason(): string
    {
        return 'E-mail is not delivered: MAIL_MAILER is "'.config('mail.default').'", so messages are only written to the application log. '
            .'Set MAIL_MAILER=smtp and the MAIL_* settings in the Environment Variables of the deployment, then redeploy.';
    }

    /**
     * Invitation state of each account, keyed by user id:
     *   status        accepted | pending | expired | not_sent
     *   expires_at    when the current link stops working (pending only)
     *   last_sent_at, delivery (sent | logged | failed | pending), error   from the latest attempt
     *
     * @param  iterable<User>  $users
     * @return array<string, array<string, mixed>>
     */
    public function summaries(iterable $users): array
    {
        $users = Collection::make($users)->filter()->values();
        if ($users->isEmpty()) {
            return [];
        }

        $emails = $users->map(static fn (User $u): string => $u->email)->unique()->values()->all();
        $tokens = DB::table((string) config('auth.passwords.invitations.table'))
            ->whereIn('email', $emails)
            ->pluck('created_at', 'email');
        $logs = NotificationLog::query()
            ->where('template_key', self::TEMPLATE_KEY)
            ->whereIn('recipient', $emails)
            ->orderByDesc('created_at')
            ->get()
            ->groupBy('recipient');

        $ttl = (int) config('auth.passwords.invitations.expire');

        return $users->mapWithKeys(static function (User $user) use ($tokens, $logs, $ttl): array {
            /** @var NotificationLog|null $last */
            $last = $logs->get($user->email)?->first();
            $tokenCreated = $tokens->get($user->email);
            $expiresAt = $tokenCreated !== null ? Carbon::parse((string) $tokenCreated)->addMinutes($ttl) : null;

            $status = match (true) {
                ! UserService::isPendingInvitation($user) => 'accepted',
                $expiresAt === null => $last !== null ? 'expired' : 'not_sent',
                $expiresAt->isPast() => 'expired',
                default => 'pending',
            };

            return [$user->id => [
                'status' => $status,
                'expires_at' => $status === 'pending' ? $expiresAt?->toIso8601String() : null,
                'last_sent_at' => $last?->created_at?->toIso8601String(),
                'delivery' => $last?->status,
                'error' => $last?->error,
            ]];
        })->all();
    }

    /** @return array<string, mixed> */
    public function summary(User $user): array
    {
        return $this->summaries([$user])[$user->id];
    }
}
