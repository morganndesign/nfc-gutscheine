<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\User;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Welcome e-mail for new staff: explains who invited them and lets them choose a password.
 * (Laravel's "reset password" e-mail would confuse people who never had an account.)
 */
final class StaffInvitation extends Notification
{
    public function __construct(
        private readonly string $token,
        private readonly string $restaurantName,
        private readonly ?string $invitedBy,
    ) {}

    /** @return list<string> */
    public function via(User $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(User $notifiable): MailMessage
    {
        $url = config('giftcard.frontend_url').'/reset-password?'.http_build_query([
            'token' => $this->token,
            'email' => $notifiable->email,
            'invite' => 1,
        ]);

        return (new MailMessage)
            ->subject("You have been invited to {$this->restaurantName} on GiftCard Pro")
            ->greeting("Hello {$notifiable->name},")
            ->line(($this->invitedBy !== null ? "{$this->invitedBy} invited you" : 'You have been invited')." to manage gift cards for {$this->restaurantName}.")
            ->action('Set your password', $url)
            ->line('This link is valid for 72 hours. If it has expired, ask your restaurant owner to resend the invitation.');
    }
}
