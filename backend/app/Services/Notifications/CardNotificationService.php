<?php

declare(strict_types=1);

namespace App\Services\Notifications;

use App\Mail\TemplatedMail;
use App\Models\GiftCard;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Services\GiftCards\CardUrlBuilder;
use App\Support\CardNumber;
use App\Support\Money;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Throwable;

final class CardNotificationService
{
    public function __construct(
        private readonly TemplateRenderer $renderer,
        private readonly CardUrlBuilder $urls,
    ) {}

    /**
     * Sends a templated email about the card to its customer. Returns false when nothing was sent.
     *
     * @param  array<string, string>  $extra
     */
    public function send(GiftCard $card, string $templateKey, array $extra = []): bool
    {
        $card->loadMissing(['restaurant.settings', 'customer']);
        $restaurant = $card->restaurant;
        $email = $card->customer?->email;

        if ($email === null || ! $restaurant->settings->send_customer_emails || $card->customer?->anonymized_at !== null) {
            return false;
        }

        $template = NotificationTemplate::resolve($restaurant->getKey(), $templateKey, $restaurant->locale);
        if ($template === null) {
            return false;
        }

        $rendered = $this->renderer->render($template, array_merge([
            'restaurant_name' => $restaurant->name,
            'customer_name' => $card->customer->full_name ?? '',
            'card_number' => CardNumber::mask($card->card_number),
            'balance' => Money::format($card->balance, $card->currency, $restaurant->locale),
            'expires_at' => $card->expires_at?->timezone($restaurant->timezone)->format('d.m.Y') ?? '—',
            'balance_url' => $this->urls->url($card),
        ], $extra));

        $log = NotificationLog::query()->create([
            'restaurant_id' => $restaurant->getKey(),
            'gift_card_id' => $card->getKey(),
            'template_key' => $templateKey,
            'channel' => 'mail',
            'recipient' => $email,
            'status' => 'pending',
        ]);

        try {
            Mail::to($email)->send(new TemplatedMail(
                $rendered['subject'],
                $rendered['html'],
                $rendered['text'],
                $restaurant->name,
                $restaurant->settings->brand_color,
                $restaurant->settings->receipt_footer,
            ));
            $log->update(['status' => 'sent', 'sent_at' => Carbon::now()]);
        } catch (Throwable $e) {
            $log->update(['status' => 'failed', 'error' => mb_substr($e->getMessage(), 0, 1000)]);

            throw $e;
        }

        return true;
    }
}
