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
                NotificationTemplate::KEY_CARD_ISSUED => [
                    'Your gift card from {{ restaurant_name }}',
                    "Hello {{ customer_name }},\n\nthank you for your purchase! Your gift card {{ card_number }} has a balance of {{ balance }} and is valid until {{ expires_at }}.\n\nYou can check your balance at any time: {{ balance_url }}\n\nWe look forward to your visit!\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_CARD_RELOADED => [
                    'Your gift card has been topped up',
                    "Hello {{ customer_name }},\n\n{{ amount }} has been added to your gift card {{ card_number }}. New balance: {{ balance }}.\n\nCheck your balance: {{ balance_url }}\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_CARD_EXPIRING => [
                    'Your gift card expires soon',
                    "Hello {{ customer_name }},\n\nyour gift card {{ card_number }} still has a balance of {{ balance }} and expires on {{ expires_at }}. We would love to welcome you before then!\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_BALANCE_LOW => [
                    'Your gift card balance is running low',
                    "Hello {{ customer_name }},\n\nthe remaining balance on your gift card {{ card_number }} is {{ balance }}.\n\n{{ restaurant_name }}",
                ],
            ],
            'de' => [
                NotificationTemplate::KEY_CARD_ISSUED => [
                    'Ihr Gutschein von {{ restaurant_name }}',
                    "Hallo {{ customer_name }},\n\nvielen Dank für Ihren Einkauf! Ihr Gutschein {{ card_number }} hat ein Guthaben von {{ balance }} und ist gültig bis {{ expires_at }}.\n\nIhr Guthaben können Sie jederzeit hier abfragen: {{ balance_url }}\n\nWir freuen uns auf Ihren Besuch!\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_CARD_RELOADED => [
                    'Ihr Gutschein wurde aufgeladen',
                    "Hallo {{ customer_name }},\n\nIhr Gutschein {{ card_number }} wurde um {{ amount }} aufgeladen. Neues Guthaben: {{ balance }}.\n\nGuthaben abfragen: {{ balance_url }}\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_CARD_EXPIRING => [
                    'Ihr Gutschein läuft bald ab',
                    "Hallo {{ customer_name }},\n\nIhr Gutschein {{ card_number }} hat noch ein Guthaben von {{ balance }} und ist gültig bis {{ expires_at }}. Wir freuen uns auf Ihren Besuch!\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_BALANCE_LOW => [
                    'Ihr Gutscheinguthaben ist fast aufgebraucht',
                    "Hallo {{ customer_name }},\n\ndas Restguthaben Ihres Gutscheins {{ card_number }} beträgt {{ balance }}.\n\n{{ restaurant_name }}",
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
