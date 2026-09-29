<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\AnonymousNotifiable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Sent to the previous address when someone else changes a user's sign-in e-mail: taking over an account by
 * changing its address and then resetting the password does not go unnoticed. Wording: lang/<locale>/account.php.
 */
final class SignInEmailChanged extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        private readonly string $name,
        private readonly string $newEmail,
        private readonly string $changedBy,
        private readonly string $restaurantName,
    ) {
        $this->onQueue('notifications');
    }

    /** @return list<string> */
    public function via(AnonymousNotifiable $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(AnonymousNotifiable $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject(__('account.email_changed.subject'))
            ->greeting(__('account.email_changed.greeting', ['name' => StaffInvitation::firstName($this->name)]))
            ->line(__('account.email_changed.body', ['changed_by' => $this->changedBy, 'restaurant' => $this->restaurantName, 'email' => $this->newEmail]))
            ->line(__('account.email_changed.signed_out'))
            ->line(__('account.email_changed.unexpected'))
            ->salutation(__('invitation.closing')."\n\n".__('invitation.signature'));
    }
}
