<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\NotificationTemplate;
use Illuminate\Database\Seeder;

final class NotificationTemplateSeeder extends Seeder
{
    public function run(): void
    {
        $templates = [
            'en' => [
                NotificationTemplate::KEY_VOUCHER_ISSUED => [
                    'Your voucher from {{ restaurant_name }}',
                    "Hello {{ customer_name }},\n\nthank you for your purchase! Your voucher is {{ validity }}.\n\nPlease bring it with you on your next visit. We look forward to seeing you!\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_RELOADED => [
                    'Your voucher has been topped up',
                    "Hello {{ customer_name }},\n\nyour voucher from {{ restaurant_name }} has just been topped up. If this was not you, please contact us.\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_EXPIRING => [
                    'Your voucher expires soon',
                    "Hello {{ customer_name }},\n\nyour voucher from {{ restaurant_name }} is valid until {{ expires_at }}. We would love to welcome you before then!\n\n{{ restaurant_name }}",
                ],
            ],
            'de' => [
                NotificationTemplate::KEY_VOUCHER_ISSUED => [
                    'Ihr Gutschein von {{ restaurant_name }}',
                    "Hallo {{ customer_name }},\n\nvielen Dank für Ihren Einkauf! Ihr Gutschein ist {{ validity }}.\n\nBitte bringen Sie ihn bei Ihrem nächsten Besuch mit. Wir freuen uns auf Sie!\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_RELOADED => [
                    'Ihr Gutschein wurde aufgeladen',
                    "Hallo {{ customer_name }},\n\nIhr Gutschein von {{ restaurant_name }} wurde soeben aufgeladen. Falls Sie das nicht waren, melden Sie sich bitte bei uns.\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_EXPIRING => [
                    'Ihr Gutschein läuft bald ab',
                    "Hallo {{ customer_name }},\n\nIhr Gutschein von {{ restaurant_name }} ist gültig bis {{ expires_at }}. Wir freuen uns auf Ihren Besuch!\n\n{{ restaurant_name }}",
                ],
            ],
        ];

        foreach ($templates as $locale => $items) {
            foreach ($items as $key => [$subject, $body]) {
                NotificationTemplate::query()->firstOrCreate(
                    ['restaurant_id' => null, 'key' => $key, 'channel' => 'mail', 'locale' => $locale],
                    ['subject' => $subject, 'body' => $body, 'is_active' => true],
                );
            }
        }
    }
}
