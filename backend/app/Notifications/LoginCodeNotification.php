<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\User;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * The 6-digit dashboard sign-in code (decision 2026-10-05). Sent right away, not from the queue: the person is
 * waiting for it on the sign-in page. Wording in lang/<locale>/login_code.php.
 */
final class LoginCodeNotification extends Notification
{
    public function __construct(private readonly string $code) {}

    /** @return list<string> */
    public function via(User $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(User $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject(__('login_code.subject', ['code' => $this->code]))
            ->greeting(__('login_code.headline'))
            ->line(__('login_code.intro'))
            ->line('# '.chunk_split($this->code, 3, ' '))
            ->line(__('login_code.expiry', ['minutes' => config('giftcard.security.login_code_minutes')]))
            ->line(__('login_code.trust', ['days' => config('giftcard.security.trusted_browser_days')]))
            ->line(__('login_code.warning'))
            ->salutation(__('login_code.signature'));
    }
}
