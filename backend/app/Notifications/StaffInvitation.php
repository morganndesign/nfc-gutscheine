<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Jobs\SendStaffInvitation;
use App\Models\User;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Str;

/**
 * Invitation e-mail for a new account: restaurant owner (created by the platform) or staff (created by the
 * restaurant). All wording lives in lang/<locale>/invitation.php; the button fallback line and the footer come
 * from lang/<locale>.json (Laravel's notification template). The language is chosen by InvitationService via
 * Notification::locale(). Sent from the queue ({@see SendStaffInvitation}); the outcome is recorded
 * in notification_logs. Names typed by users are Markdown-escaped ({@see MarkdownText}).
 */
final class StaffInvitation extends Notification
{
    public function __construct(
        private readonly string $token,
        private readonly string $restaurantName,
        private readonly ?string $invitedBy,
        private readonly bool $forOwner = false,
        private readonly ?string $supportEmail = null,
    ) {}

    /** @return list<string> */
    public function via(User $notifiable): array
    {
        return ['mail'];
    }

    public function token(): string
    {
        return $this->token;
    }

    public function toMail(User $notifiable): MailMessage
    {
        // Token in the URL fragment: browsers never send it to a server, so it cannot end up in access logs,
        // proxies or Referer headers (audit L1).
        $url = config('giftcard.frontend_url').'/reset-password#'.http_build_query([
            'token' => $this->token,
            'email' => $notifiable->email,
            'invite' => 1,
        ]);

        $restaurant = ['restaurant' => MarkdownText::escape($this->restaurantName)];
        $body = match (true) {
            $this->forOwner => __('invitation.body_owner', $restaurant),
            $this->invitedBy !== null => __('invitation.body_staff', $restaurant + ['inviter' => MarkdownText::escape($this->invitedBy)]),
            default => __('invitation.body_staff_anonymous', $restaurant),
        };

        $message = (new MailMessage)
            ->subject(__('invitation.subject'))
            ->greeting(__('invitation.headline'))
            ->line(__('invitation.greeting', ['name' => MarkdownText::escape(self::firstName($notifiable->name))]))
            ->line($body)
            ->line(__('invitation.instruction'))
            ->action(__('invitation.action'), $url)
            ->line(__('invitation.expiry'));

        // Owners contact the platform; staff ask their own restaurant.
        if (! $this->forOwner) {
            $message->line(__('invitation.support_staff'));
        } elseif ($this->supportEmail !== null) {
            $message->line(__('invitation.support'))->line("[{$this->supportEmail}](mailto:{$this->supportEmail})");
        }

        return $message->salutation(__('invitation.closing')."\n\n".__('invitation.signature'));
    }

    /** "Hanna Maria Hirsch" → "Hanna"; a single word is used as it is. */
    public static function firstName(string $name): string
    {
        $first = Str::of($name)->squish()->before(' ')->toString();

        return $first !== '' ? $first : $name;
    }
}
