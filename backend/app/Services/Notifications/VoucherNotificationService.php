<?php

declare(strict_types=1);

namespace App\Services\Notifications;

use App\Enums\MediumStatus;
use App\Enums\VoucherKind;
use App\Mail\TemplatedMail;
use App\Models\Medium;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Models\Payment;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Media\PrintableQrService;
use App\Services\Vouchers\VoucherPdf;
use App\Support\Money;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use SensitiveParameter;
use Throwable;

/**
 * Guest e-mails about a voucher. A sale or reload is confirmed like a receipt: amount, restaurant, date and how it
 * was paid (ADR-003). The sale of a digital voucher also carries the voucher itself, as the PDF of the printed
 * sheet with its QR (decision 2026-10-04): the guest gets it the moment it is sold, the only time its QR exists.
 * Never in the text: no QR payload, voucher number, link, token or code, and no balance (it lives on the server).
 */
final class VoucherNotificationService
{
    /** @var array<'de'|'en'|'bs', array{no_expiry: string, valid_until: string, method: array<string, string>, attached: string}> */
    private const TEXT = [
        'de' => [
            'no_expiry' => 'unbefristet gültig',
            'valid_until' => 'gültig bis',
            'method' => ['cash' => 'Bar', 'card_terminal' => 'Karte', 'bank_transfer' => 'Überweisung', 'complimentary' => 'Geschenk des Hauses'],
            'attached' => 'Ihr Gutschein ist als PDF angehängt. Bitte bewahren Sie ihn wie Bargeld auf.',
        ],
        'en' => [
            'no_expiry' => 'valid without an expiry date',
            'valid_until' => 'valid until',
            'method' => ['cash' => 'Cash', 'card_terminal' => 'Card', 'bank_transfer' => 'Bank transfer', 'complimentary' => 'Compliments of the house'],
            'attached' => 'Your voucher is attached as a PDF. Please keep it safe like cash.',
        ],
        'bs' => [
            'no_expiry' => 'bez roka važenja',
            'valid_until' => 'vrijedi do',
            'method' => ['cash' => 'Gotovina', 'card_terminal' => 'Kartica', 'bank_transfer' => 'Bankovni transfer', 'complimentary' => 'Poklon kuće'],
            'attached' => 'Vaš vaučer je u prilogu kao PDF. Čuvajte ga kao gotovinu.',
        ],
    ];

    public function __construct(
        private readonly TemplateRenderer $renderer,
        private readonly VoucherPdf $pdf,
    ) {}

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
    public function send(Voucher $voucher, string $templateKey, ?string $transactionId = null, #[SensitiveParameter] ?string $printablePayload = null): bool
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
            'date' => Carbon::now()->timezone($restaurant->timezone)->format('d.m.Y'),
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
            /** @var Payment|null $payment */
            $payment = $transaction->payment_id !== null ? Payment::query()->withoutGlobalScopes()->find($transaction->payment_id) : null;
            $method = $payment?->method;

            // The money that moved: received for a sale or reload, paid back with a refund.
            $variables['amount'] = Money::format($payment->amount ?? abs($transaction->amount), $voucher->currency, $restaurant->locale);
            $variables['date'] = $transaction->created_at->timezone($restaurant->timezone)->format('d.m.Y');
            $variables['payment_method'] = $method !== null ? self::TEXT[$language]['method'][$method->value] : '—';
        }

        $rendered = $this->renderer->render($template, $variables);
        $voucherPdf = $this->voucherPdf($voucher, $templateKey, $printablePayload);

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
                $language,
                $voucherPdf,
                $voucherPdf !== null ? self::TEXT[$language]['attached'] : null,
            ));
            $log->update(['status' => 'sent', 'sent_at' => Carbon::now()]);
        } catch (Throwable $e) {
            $log->update(['status' => 'failed', 'error' => mb_substr($e->getMessage(), 0, 1000)]);

            throw $e;
        }

        return true;
    }

    /**
     * The sale's voucher sheet, when the QR is still the voucher's active one (a QR issued again before the e-mail
     * left replaced it: then the confirmation goes without it).
     *
     * @return array{string, string}|null
     */
    private function voucherPdf(Voucher $voucher, string $templateKey, #[SensitiveParameter] ?string $payload): ?array
    {
        if ($payload === null || $templateKey !== NotificationTemplate::KEY_VOUCHER_ISSUED || $voucher->kind !== VoucherKind::Digital) {
            return null;
        }
        $hash = PrintableQrService::hashOf($payload);
        $active = $hash !== null && Medium::query()->withoutGlobalScopes()
            ->where('voucher_id', $voucher->getKey())
            ->where('secret_hash', $hash)
            ->where('status', MediumStatus::Active)
            ->exists();

        return $active ? [$this->pdf->fileName($voucher), $this->pdf->render($voucher, $payload)] : null;
    }
}
