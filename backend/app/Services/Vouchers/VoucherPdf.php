<?php

declare(strict_types=1);

namespace App\Services\Vouchers;

use App\Models\RestaurantLogo;
use App\Models\Voucher;
use App\Support\Money;
use Dompdf\Dompdf;
use Dompdf\Options;
use SensitiveParameter;

/**
 * The printable voucher as a PDF, for the guest's e-mail: the restaurant's brand colours, headline, message and
 * logo, the value that was bought (ADR-003), the recipient and the QR. Like the printed sheet it never shows the
 * voucher number: the QR is the voucher. Rendered locally (no remote resources), in the restaurant's language.
 */
final class VoucherPdf
{
    /** @var array<'de'|'en'|'bs', array<string, string>> Same wording as the printed sheet (dashboard guest-copy). */
    private const COPY = [
        'de' => [
            'voucher' => 'Gutschein', 'headline' => 'Ein Geschenk für Sie', 'value' => 'Wert', 'for' => 'für',
            'howTo' => 'Bitte zeigen Sie diesen Code beim Bezahlen vor.',
            'keepSafe' => 'Wie Bargeld aufbewahren: Wer den Code besitzt, kann den Gutschein einlösen.',
            'noExpiry' => 'Unbefristet gültig', 'validUntil' => 'Gültig bis', 'file' => 'Gutschein', 'open' => '„', 'close' => '“',
        ],
        'en' => [
            'voucher' => 'Voucher', 'headline' => 'A gift for you', 'value' => 'Value', 'for' => 'for',
            'howTo' => 'Please show this code when you pay.',
            'keepSafe' => 'Keep it safe like cash: whoever holds the code can redeem the voucher.',
            'noExpiry' => 'No expiry date', 'validUntil' => 'Valid until', 'file' => 'Voucher', 'open' => '“', 'close' => '”',
        ],
        'bs' => [
            'voucher' => 'Vaučer', 'headline' => 'Poklon za vas', 'value' => 'Vrijednost', 'for' => 'za',
            'howTo' => 'Molimo pokažite ovaj kôd prilikom plaćanja.',
            'keepSafe' => 'Čuvajte ga kao gotovinu: ko ima kôd, može iskoristiti vaučer.',
            'noExpiry' => 'Bez roka važenja', 'validUntil' => 'Vrijedi do', 'file' => 'Vaucer', 'open' => '„', 'close' => '“',
        ],
    ];

    public function __construct(private readonly QrCodeService $qr) {}

    /** @return 'de'|'en'|'bs' */
    public static function language(?string $locale): string
    {
        return match (strtolower(substr($locale ?? 'de', 0, 2))) {
            'de' => 'de',
            'bs', 'hr', 'sr' => 'bs',
            default => 'en',
        };
    }

    /** File name of the attachment, e.g. "Gutschein-Trattoria-Bella-Vista.pdf". */
    public function fileName(Voucher $voucher): string
    {
        $restaurant = $voucher->restaurant;
        $slug = trim((string) preg_replace('/[^A-Za-z0-9]+/', '-', iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $restaurant->name) ?: ''), '-');

        return self::COPY[self::language($restaurant->locale)]['file'].($slug !== '' ? '-'.mb_substr($slug, 0, 60) : '').'.pdf';
    }

    /** The PDF bytes of [voucher]'s sheet with its QR [payload]. */
    public function render(Voucher $voucher, #[SensitiveParameter] string $payload): string
    {
        $options = new Options;
        // Only our own markup with inline data: no remote fetches, no PHP or JavaScript in the document.
        $options->setIsRemoteEnabled(false);
        $options->setIsPhpEnabled(false);
        $options->setIsJavascriptEnabled(false);
        $options->setDefaultFont('DejaVu Sans');
        $options->setChroot([resource_path('views/pdf')]);
        $options->setFontCache(storage_path('framework/cache'));
        $options->setTempDir(sys_get_temp_dir());

        $pdf = new Dompdf($options);
        $pdf->loadHtml($this->html($voucher, $payload), 'UTF-8');
        // A5 for every restaurant: a card on a letter, printable at home on A4 as well.
        $pdf->setPaper('A5');
        $pdf->render();

        return (string) $pdf->output();
    }

    /** The sheet's markup (the PDF's text is compressed, so tests read this). */
    public function html(Voucher $voucher, #[SensitiveParameter] string $payload): string
    {
        $voucher->loadMissing('restaurant.settings');
        $restaurant = $voucher->restaurant;
        $settings = $restaurant->settings;
        $copy = self::COPY[self::language($restaurant->locale)];
        $brand = self::hex($settings->brand_color, '#0F172A');
        $accent = self::hex($settings->accent_color, '#C9A86A');
        $expiresAt = $voucher->expires_at?->timezone($restaurant->timezone)->format('d.m.Y');
        /** @var RestaurantLogo|null $logo */
        $logo = RestaurantLogo::query()->where('restaurant_id', $restaurant->getKey())->first();

        return view('pdf.voucher', [
            'language' => self::language($restaurant->locale),
            'copy' => $copy,
            'restaurantName' => $restaurant->name,
            'logo' => $logo !== null ? 'data:'.$logo->mime.';base64,'.$logo->data : null,
            'headline' => trim((string) $settings->voucher_headline) !== '' ? trim((string) $settings->voucher_headline) : $copy['headline'],
            'recipient' => self::text($voucher->recipient_name),
            // The buyer's own words come first; otherwise the restaurant's message for every voucher.
            'message' => self::text($voucher->gift_message) ?? self::text($settings->voucher_message),
            'personal' => self::text($voucher->gift_message) !== null,
            'value' => Money::format($voucher->initial_value, $voucher->currency, $restaurant->locale),
            'validity' => $expiresAt !== null ? $copy['validUntil'].' '.$expiresAt : $copy['noExpiry'],
            'qr' => 'data:image/png;base64,'.base64_encode($this->qr->png($payload)),
            'brand' => $brand,
            'ink' => self::inkOn($brand),
            'accent' => self::contrast($brand, $accent) >= 2.2 ? $accent : self::inkOn($brand),
            'rule' => self::contrast('#ffffff', $accent) >= 2.2 ? $accent : '#141414',
        ])->render();
    }

    private static function text(?string $value): ?string
    {
        return $value !== null && trim($value) !== '' ? trim($value) : null;
    }

    private static function hex(?string $value, string $fallback): string
    {
        return is_string($value) && preg_match('/^#[0-9a-fA-F]{6}$/', $value) === 1 ? $value : $fallback;
    }

    private static function luminance(string $hex): float
    {
        $sum = 0.0;
        foreach ([[1, 0.2126], [3, 0.7152], [5, 0.0722]] as [$at, $weight]) {
            $c = hexdec(substr($hex, $at, 2)) / 255;
            $sum += $weight * ($c <= 0.03928 ? $c / 12.92 : (($c + 0.055) / 1.055) ** 2.4);
        }

        return $sum;
    }

    private static function contrast(string $a, string $b): float
    {
        [$x, $y] = [self::luminance($a), self::luminance($b)];

        return (max($x, $y) + 0.05) / (min($x, $y) + 0.05);
    }

    /** Readable ink on a background: white or near-black, whichever contrasts more (as on the printed sheet). */
    private static function inkOn(string $background): string
    {
        return self::contrast($background, '#ffffff') >= self::contrast($background, '#141414') ? '#ffffff' : '#141414';
    }
}
