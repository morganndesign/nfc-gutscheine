<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\User;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Tells the owners that a POS system was connected to their restaurant (so a code used by the wrong company is
 * noticed). Wording in lang/<locale>/partner.php.
 */
final class PartnerConnectedNotification extends Notification
{
    public function __construct(
        private readonly string $partner,
        private readonly string $restaurant,
    ) {}

    /** @return list<string> */
    public function via(User $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(User $notifiable): MailMessage
    {
        $replace = [
            'partner' => MarkdownText::escape(str_replace(['*', '_'], ['\*', '\_'], $this->partner)),
            'restaurant' => MarkdownText::escape(str_replace(['*', '_'], ['\*', '\_'], $this->restaurant)),
        ];

        return (new MailMessage)
            ->subject(__('partner.mail.connected.subject', $replace))
            ->greeting(__('partner.mail.connected.headline'))
            ->line(__('partner.mail.connected.intro', $replace))
            ->line(__('partner.mail.connected.next'))
            ->salutation(__('partner.mail.signature'));
    }
}
