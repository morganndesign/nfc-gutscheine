<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Audit 2026-10-06 (T4, T9): the default guest e-mails say "payment method" instead of "paid" (a loyalty voucher was
 * not paid), English starts the sentence after the greeting with a capital letter, and the German card e-mail says
 * "Karte" instead of "Geschenkkarte". Only the platform's default templates; a restaurant's own templates stay.
 */
return new class extends Migration
{
    /** @var array<string, list<array{0: string, 1: string}>> */
    private const REPLACE = [
        'en' => [["\n\nthank you for", "\n\nThank you for"], ["\n\nyour voucher", "\n\nYour voucher"], ["\n\nyour gift card", "\n\nYour gift card"], ["\nPaid: {{ payment_method }}", "\nPayment: {{ payment_method }}"]],
        'de' => [["\nBezahlt: {{ payment_method }}", "\nZahlungsart: {{ payment_method }}"], ['Ihre Geschenkkarte von', 'Ihre Karte von']],
        'bs' => [["\nPlaćeno: {{ payment_method }}", "\nNačin plaćanja: {{ payment_method }}"]],
    ];

    public function up(): void
    {
        foreach (self::REPLACE as $locale => $pairs) {
            $rows = DB::table('notification_templates')->whereNull('restaurant_id')->where('locale', $locale)->get(['id', 'subject', 'body']);
            foreach ($rows as $row) {
                $subject = (string) $row->subject;
                $body = (string) $row->body;
                foreach ($pairs as [$from, $to]) {
                    $subject = str_replace($from, $to, $subject);
                    $body = str_replace($from, $to, $body);
                }
                if ($subject !== $row->subject || $body !== $row->body) {
                    DB::table('notification_templates')->where('id', $row->id)->update(['subject' => $subject, 'body' => $body]);
                }
            }
        }
    }

    public function down(): void
    {
        // Wording only; nothing to undo.
    }
};
