<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\User;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Tells the restaurant what happened to its card order (audit K8): accepted, declined (with the platform's reason)
 * or shipped (confirm the delivery in the app). Same look as the account e-mails; wording in
 * lang/<locale>/card_order_update.php.
 */
final class CardOrderUpdateNotification extends Notification
{
    /** @param 'accepted'|'declined'|'shipped' $kind */
    public function __construct(
        private readonly string $kind,
        private readonly string $restaurant,
        private readonly int $quantity,
        private readonly ?string $batchCode = null,
        private readonly ?string $reason = null,
    ) {}

    /** @return list<string> */
    public function via(User $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(User $notifiable): MailMessage
    {
        $replace = ['restaurant' => $this->restaurant, 'quantity' => (string) $this->quantity, 'batch' => (string) $this->batchCode];
        $message = (new MailMessage)
            ->subject(__("card_order_update.{$this->kind}.subject", $replace))
            ->greeting(__("card_order_update.{$this->kind}.headline"))
            ->line(__("card_order_update.{$this->kind}.intro", [
                'restaurant' => MarkdownText::escape(str_replace(['*', '_'], ['\*', '\_'], $this->restaurant)),
                'quantity' => (string) $this->quantity,
                'batch' => (string) $this->batchCode,
            ]));
        if ($this->reason !== null && $this->reason !== '') {
            $message->line('**'.__('card_order_update.reason').':** '.MarkdownText::escape(str_replace(['*', '_', "\r", "\n"], ['\*', '\_', ' ', ' '], $this->reason)));
        }

        return $message
            ->line(__("card_order_update.{$this->kind}.next"))
            ->salutation(__('card_order_update.signature'));
    }
}
