<?php

declare(strict_types=1);

namespace App\Services\Notifications;

use App\Mail\TemplatedMail;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Models\Voucher;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * Guest e-mails about a voucher. They never carry a balance, an amount, the voucher number or a link to the
 * voucher (architecture §6.4).
 */
final class VoucherNotificationService
{
    public function __construct(private readonly TemplateRenderer $renderer) {}

    /**
     * Sends a templated e-mail about the voucher to its customer. Returns false when nothing was sent.
     */
    public function send(Voucher $voucher, string $templateKey): bool
    {
        $voucher->loadMissing(['restaurant.settings', 'customer']);
        $restaurant = $voucher->restaurant;
        $email = $voucher->customer?->email;

        if ($email === null || ! $restaurant->settings->send_customer_emails || $voucher->customer?->anonymized_at !== null) {
            return false;
        }

        $template = NotificationTemplate::resolve($restaurant->getKey(), $templateKey, $restaurant->locale);
        if ($template === null) {
            return false;
        }

        $german = str_starts_with($template->locale, 'de');
        $expiresAt = $voucher->expires_at?->timezone($restaurant->timezone)->format('d.m.Y');

        $rendered = $this->renderer->render($template, [
            'restaurant_name' => $restaurant->name,
            'customer_name' => $voucher->customer->full_name ?? '',
            'expires_at' => $expiresAt ?? '—',
            'validity' => match (true) {
                $expiresAt === null && $german => 'unbefristet gültig',
                $expiresAt === null => 'valid without an expiry date',
                $german => 'gültig bis '.$expiresAt,
                default => 'valid until '.$expiresAt,
            },
        ]);

        $log = NotificationLog::query()->create([
            'restaurant_id' => $restaurant->getKey(),
            'voucher_id' => $voucher->getKey(),
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
