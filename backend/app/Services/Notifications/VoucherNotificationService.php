<?php

declare(strict_types=1);

namespace App\Services\Notifications;

use App\Enums\PaymentMethod;
use App\Mail\TemplatedMail;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Models\Payment;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Support\Money;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * Guest e-mails about a voucher. A sale or reload is confirmed like a receipt: amount, restaurant, date and how it
 * was paid (ADR-003). Nothing in an e-mail proves or spends the voucher: no QR payload, voucher number, link,
 * token or code, and no balance (the balance lives on the server).
 */
final class VoucherNotificationService
{
    /** @var array<'de'|'en'|'bs', array{no_expiry: string, valid_until: string, method: array<string, string>}> */
    private const TEXT = [
        'de' => [
            'no_expiry' => 'unbefristet gültig',
            'valid_until' => 'gültig bis',
            'method' => ['cash' => 'Bar', 'card_terminal' => 'Karte', 'bank_transfer' => 'Überweisung', 'complimentary' => 'Geschenk des Hauses'],
        ],
        'en' => [
            'no_expiry' => 'valid without an expiry date',
            'valid_until' => 'valid until',
            'method' => ['cash' => 'Cash', 'card_terminal' => 'Card', 'bank_transfer' => 'Bank transfer', 'complimentary' => 'Compliments of the house'],
        ],
        'bs' => [
            'no_expiry' => 'bez roka važenja',
            'valid_until' => 'vrijedi do',
            'method' => ['cash' => 'Gotovina', 'card_terminal' => 'Kartica', 'bank_transfer' => 'Bankovni transfer', 'complimentary' => 'Poklon kuće'],
        ],
    ];

    public function __construct(private readonly TemplateRenderer $renderer) {}

    /** @return 'de'|'en'|'bs' */
    private static function language(string $locale): string
    {
        return match (strtolower(substr($locale, 0, 2))) {
            'de' => 'de',
            'bs', 'hr', 'sr' => 'bs',
            default => 'en',
        };
    }

    /**
     * Sends a templated e-mail about the voucher to its customer. Returns false when nothing was sent.
     */
    public function send(Voucher $voucher, string $templateKey, ?string $transactionId = null): bool
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

        $language = self::language($template->locale);
        $expiresAt = $voucher->expires_at?->timezone($restaurant->timezone)->format('d.m.Y');

        $variables = [
            'restaurant_name' => $restaurant->name,
            'customer_name' => $voucher->customer->full_name ?? '',
            'expires_at' => $expiresAt ?? '—',
            'validity' => match (true) {
                $expiresAt === null => self::TEXT[$language]['no_expiry'],
                default => self::TEXT[$language]['valid_until'].' '.$expiresAt,
            },
        ];

        if ($transactionId !== null) {
            /** @var VoucherTransaction|null $transaction */
            $transaction = VoucherTransaction::query()->withoutGlobalScopes()
                ->whereKey($transactionId)
                ->where('voucher_id', $voucher->getKey())
                ->first();
            if ($transaction === null) {
                return false;
            }
            $method = $transaction->payment_id !== null
                ? Payment::query()->withoutGlobalScopes()->whereKey($transaction->payment_id)->value('method')
                : null;
            $method = $method instanceof PaymentMethod ? $method : (is_string($method) ? PaymentMethod::tryFrom($method) : null);

            $variables['amount'] = Money::format(abs($transaction->amount), $voucher->currency, $restaurant->locale);
            $variables['date'] = $transaction->created_at->timezone($restaurant->timezone)->format('d.m.Y');
            $variables['payment_method'] = $method !== null ? self::TEXT[$language]['method'][$method->value] : '—';
        }

        $rendered = $this->renderer->render($template, $variables);

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
