<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\CardOrder;
use App\Models\User;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Tells a platform admin that a restaurant ordered cards (same look as the other account e-mails). Wording in
 * lang/<locale>/card_order.php; names and notes typed by users are Markdown-escaped ({@see MarkdownText}).
 */
final class CardOrderNotification extends Notification
{
    public function __construct(private readonly CardOrder $order) {}

    /** @return list<string> */
    public function via(User $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(User $notifiable): MailMessage
    {
        $order = $this->order;
        $restaurant = MarkdownText::escape(self::bold($order->restaurant->name));
        $quantity = (string) $order->quantity;

        $message = (new MailMessage)
            ->subject(__('card_order.subject', ['restaurant' => $order->restaurant->name, 'quantity' => $quantity]))
            ->greeting(__('card_order.headline'))
            ->line(__('card_order.intro', ['restaurant' => $restaurant, 'quantity' => $quantity]));

        // Restaurant and quantity are in the sentence above; the details below.
        $rows = [
            __('card_order.at') => $order->created_at->timezone($order->restaurant->timezone)->format('d.m.Y, H:i'),
        ];
        if ($order->requester !== null) {
            $rows[__('card_order.by')] = MarkdownText::escape(self::bold($order->requester->name));
        }
        if ($order->note !== null) {
            $rows[__('card_order.note')] = MarkdownText::escape(self::bold(str_replace(["\r", "\n"], ' ', $order->note)));
        }
        // One line per detail (Laravel's mail lines are paragraphs; Markdown tables are not rendered there).
        foreach ($rows as $label => $value) {
            $message->line('**'.$label.':** '.$value);
        }

        return $message
            ->action(__('card_order.action'), config('giftcard.frontend_url').'/admin/card-batches#orders')
            ->line(__('card_order.next'))
            ->salutation(__('card_order.signature'));
    }

    /** Asterisks and underscores in a typed value must not turn into Markdown emphasis. */
    private static function bold(string $value): string
    {
        return str_replace(['*', '_'], ['\*', '\_'], $value);
    }
}
