<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\User;
use App\Support\Money;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Tells the owners about an online payment that needs them: a disputed payment (the voucher is blocked) or a refund
 * made in the provider's own dashboard (the voucher is blocked until it is closed here). Wording in
 * lang/<locale>/online.php.
 */
final class OnlinePaymentNotification extends Notification
{
    /** @param 'dispute'|'refunded_elsewhere' $kind */
    public function __construct(
        private readonly string $kind,
        private readonly string $restaurant,
        private readonly string $voucherNumber,
        private readonly int $amount,
        private readonly string $currency,
    ) {}

    /** @return list<string> */
    public function via(User $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(User $notifiable): MailMessage
    {
        $replace = [
            'restaurant' => MarkdownText::escape(str_replace(['*', '_'], ['\*', '\_'], $this->restaurant)),
            'voucher' => $this->voucherNumber,
            'amount' => Money::format($this->amount, $this->currency, (string) ($notifiable->locale ?? 'de')),
        ];

        return (new MailMessage)
            ->subject(__("online.mail.{$this->kind}.subject", $replace))
            ->greeting(__("online.mail.{$this->kind}.headline"))
            ->line(__("online.mail.{$this->kind}.intro", $replace))
            ->line(__("online.mail.{$this->kind}.next"))
            ->salutation(__('online.mail.signature'));
    }
}
