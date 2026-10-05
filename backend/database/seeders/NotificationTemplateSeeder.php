<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\NotificationTemplate;
use Illuminate\Database\Seeder;

final class NotificationTemplateSeeder extends Seeder
{
    public function run(): void
    {
        // Receipts: amount, restaurant, date, payment. Never a QR payload, voucher number, link, token or balance.
        $templates = [
            'en' => [
                NotificationTemplate::KEY_VOUCHER_ISSUED => [
                    'Your voucher from {{ restaurant_name }} – {{ amount }}',
                    "Hello {{ customer_name }},\n\nThank you for your voucher from {{ restaurant_name }}.\n\nValue: {{ amount }}\nDate: {{ date }}\nPayment: {{ payment_method }}\n\nYour voucher is {{ validity }}. Please keep the printed voucher safe like cash: it is what you redeem. This e-mail cannot be used to pay.\n\nWe look forward to your visit!\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_RELOADED => [
                    'Your voucher from {{ restaurant_name }} was topped up – {{ amount }}',
                    "Hello {{ customer_name }},\n\nYour voucher from {{ restaurant_name }} was topped up.\n\nAmount: {{ amount }}\nDate: {{ date }}\nPayment: {{ payment_method }}\n\nIf this was not you, please contact us.\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_EXPIRING => [
                    'Your voucher expires soon',
                    "Hello {{ customer_name }},\n\nYour voucher from {{ restaurant_name }} is valid until {{ expires_at }}. We would love to welcome you before then!\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_CARD_REPLACED => [
                    'Your gift card from {{ restaurant_name }} was replaced',
                    "Hello {{ customer_name }},\n\nYour gift card from {{ restaurant_name }} was replaced by a new card on {{ date }}. The balance is now on the new card; the old card no longer works.\n\nIf you did not ask for this, please contact us right away.\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_REFUNDED => [
                    'Your voucher from {{ restaurant_name }} was refunded – {{ amount }}',
                    "Hello {{ customer_name }},\n\nYour voucher from {{ restaurant_name }} was refunded and is now closed.\n\nPaid back: {{ amount }}\nDate: {{ date }}\nPaid by: {{ payment_method }}\n\nIf this was not you, please contact us.\n\n{{ restaurant_name }}",
                ],
            ],
            'de' => [
                NotificationTemplate::KEY_VOUCHER_ISSUED => [
                    'Ihr Gutschein von {{ restaurant_name }} – {{ amount }}',
                    "Hallo {{ customer_name }},\n\nvielen Dank für Ihren Gutschein von {{ restaurant_name }}.\n\nWert: {{ amount }}\nDatum: {{ date }}\nZahlungsart: {{ payment_method }}\n\nIhr Gutschein ist {{ validity }}. Bitte bewahren Sie den gedruckten Gutschein wie Bargeld auf: Mit ihm wird eingelöst. Mit dieser E-Mail kann nicht bezahlt werden.\n\nWir freuen uns auf Ihren Besuch!\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_RELOADED => [
                    'Ihr Gutschein von {{ restaurant_name }} wurde aufgeladen – {{ amount }}',
                    "Hallo {{ customer_name }},\n\nIhr Gutschein von {{ restaurant_name }} wurde aufgeladen.\n\nBetrag: {{ amount }}\nDatum: {{ date }}\nZahlungsart: {{ payment_method }}\n\nFalls Sie das nicht waren, melden Sie sich bitte bei uns.\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_EXPIRING => [
                    'Ihr Gutschein läuft bald ab',
                    "Hallo {{ customer_name }},\n\nIhr Gutschein von {{ restaurant_name }} ist gültig bis {{ expires_at }}. Wir freuen uns auf Ihren Besuch!\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_CARD_REPLACED => [
                    'Ihre Karte von {{ restaurant_name }} wurde ersetzt',
                    "Hallo {{ customer_name }},\n\nIhre Karte von {{ restaurant_name }} wurde am {{ date }} durch eine neue Karte ersetzt. Das Guthaben ist jetzt auf der neuen Karte; die alte Karte funktioniert nicht mehr.\n\nFalls Sie das nicht veranlasst haben, melden Sie sich bitte umgehend bei uns.\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_REFUNDED => [
                    'Ihr Gutschein von {{ restaurant_name }} wurde erstattet – {{ amount }}',
                    "Hallo {{ customer_name }},\n\nIhr Gutschein von {{ restaurant_name }} wurde erstattet und ist damit geschlossen.\n\nErstattet: {{ amount }}\nDatum: {{ date }}\nAusgezahlt per: {{ payment_method }}\n\nFalls Sie das nicht waren, melden Sie sich bitte bei uns.\n\n{{ restaurant_name }}",
                ],
            ],
            'bs' => [
                NotificationTemplate::KEY_VOUCHER_ISSUED => [
                    'Vaš vaučer od {{ restaurant_name }} – {{ amount }}',
                    "Zdravo {{ customer_name }},\n\nhvala na vaučeru od {{ restaurant_name }}.\n\nVrijednost: {{ amount }}\nDatum: {{ date }}\nNačin plaćanja: {{ payment_method }}\n\nVaš vaučer je {{ validity }}. Čuvajte ispisani vaučer kao gotovinu: njime se plaća. Ovim e-mailom se ne može platiti.\n\nRadujemo se Vašoj posjeti!\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_RELOADED => [
                    'Vaš vaučer od {{ restaurant_name }} je dopunjen – {{ amount }}',
                    "Zdravo {{ customer_name }},\n\nVaš vaučer od {{ restaurant_name }} je dopunjen.\n\nIznos: {{ amount }}\nDatum: {{ date }}\nNačin plaćanja: {{ payment_method }}\n\nAko to niste bili Vi, molimo javite nam se.\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_EXPIRING => [
                    'Vaš vaučer uskoro ističe',
                    "Zdravo {{ customer_name }},\n\nVaš vaučer od {{ restaurant_name }} vrijedi do {{ expires_at }}. Radujemo se Vašoj posjeti!\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_CARD_REPLACED => [
                    'Vaša poklon kartica od {{ restaurant_name }} je zamijenjena',
                    "Zdravo {{ customer_name }},\n\nVaša poklon kartica od {{ restaurant_name }} je {{ date }} zamijenjena novom karticom. Stanje je sada na novoj kartici; stara kartica više ne radi.\n\nAko to niste tražili, molimo odmah nam se javite.\n\n{{ restaurant_name }}",
                ],
                NotificationTemplate::KEY_VOUCHER_REFUNDED => [
                    'Vaš vaučer od {{ restaurant_name }} je refundiran – {{ amount }}',
                    "Zdravo {{ customer_name }},\n\nVaš vaučer od {{ restaurant_name }} je refundiran i time zatvoren.\n\nVraćeno: {{ amount }}\nDatum: {{ date }}\nIsplaćeno: {{ payment_method }}\n\nAko to niste bili Vi, molimo javite nam se.\n\n{{ restaurant_name }}",
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
