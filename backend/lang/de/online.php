<?php

declare(strict_types=1);

return [
    'product' => 'Gutschein – :restaurant',
    'max_amount' => 'Der Höchstbetrag muss zwischen :min und :max Cent liegen.',
    'amounts' => 'Jeder Betrag muss zwischen :min und :max Cent liegen.',
    'not_connected' => 'Zuerst das Stripe-Konto verbinden und die Freischaltung durch Stripe abwarten.',
    'legal_missing' => 'Für den Online-Verkauf braucht der Shop Links zu AGB und Impressum des Lokals.',
    'mail' => [
        'signature' => 'Ihr GiftCard Pro Team',
        'dispute' => [
            'subject' => 'Online-Zahlung beanstandet: Gutschein :voucher gesperrt',
            'headline' => 'Eine Online-Zahlung wurde beanstandet',
            'intro' => 'Der Karteninhaber hat die Zahlung von **:amount** für einen Online-Gutschein von **:restaurant** beanstandet (Gutschein :voucher). Der Gutschein ist gesperrt und kann nicht mehr bezahlen.',
            'next' => 'Bitte die Beanstandung in Ihrem Stripe-Dashboard beantworten. Wird sie zurückgezogen, können Sie den Gutschein im Dashboard wieder entsperren.',
        ],
        'refunded_elsewhere' => [
            'subject' => 'In Stripe erstattet: Gutschein :voucher gesperrt',
            'headline' => 'Eine Online-Zahlung wurde in Stripe erstattet',
            'intro' => 'Für den Online-Gutschein :voucher von **:restaurant** (**:amount**) wurde direkt in Stripe Geld zurückgezahlt. Der Gutschein ist deshalb gesperrt.',
            'next' => 'Bitte im Dashboard beim Gutschein prüfen und ihn erstatten oder wieder entsperren.',
        ],
    ],
];
