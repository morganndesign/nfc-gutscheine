<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\User;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Welcome e-mail for a new account: explains who invited them and lets them choose a password.
 * (Laravel's "reset password" e-mail would confuse people who never had an account.)
 * Sent synchronously by InvitationService, which records the outcome in notification_logs.
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
        $url = config('giftcard.frontend_url').'/reset-password?'.http_build_query([
            'token' => $this->token,
            'email' => $notifiable->email,
            'invite' => 1,
        ]);

        $who = $this->invitedBy !== null ? "{$this->invitedBy} invited you" : 'You have been invited';
        $expired = match (true) {
            ! $this->forOwner => 'ask your restaurant owner to resend the invitation.',
            $this->supportEmail !== null => "write to {$this->supportEmail} for a new invitation.",
            default => 'contact GiftCard Pro support for a new invitation.',
        };

        return (new MailMessage)
            ->subject("You have been invited to {$this->restaurantName} on GiftCard Pro")
            ->greeting("Hello {$notifiable->name},")
            ->line($this->forOwner
                ? "{$who} to set up {$this->restaurantName} on GiftCard Pro. Your account is the owner account of the restaurant."
                : "{$who} to manage gift cards for {$this->restaurantName}.")
            ->action('Set your password', $url)
            ->line("This link is valid for 72 hours and works once. If it has expired, {$expired}");
    }
}
