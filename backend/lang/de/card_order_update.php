<?php

declare(strict_types=1);

return [
    'accepted' => [
        'subject' => 'Kartenbestellung angenommen: :quantity Karten',
        'headline' => 'Ihre Kartenbestellung ist angenommen',
        'intro' => 'Die Bestellung von **:quantity Karten** für **:restaurant** ist angenommen (Serie :batch). Die Karten werden jetzt hergestellt.',
        'next' => 'Sobald die Karten unterwegs sind, erhalten Sie eine weitere E-Mail.',
    ],
    'declined' => [
        'subject' => 'Kartenbestellung abgelehnt: :quantity Karten',
        'headline' => 'Ihre Kartenbestellung wurde abgelehnt',
        'intro' => 'Die Bestellung von **:quantity Karten** für **:restaurant** wurde abgelehnt.',
        'next' => 'Bei Fragen antworten Sie einfach auf diese E-Mail oder bestellen Sie erneut in der App unter Karten.',
    ],
    'shipped' => [
        'subject' => 'Ihre Karten sind unterwegs: :quantity Karten',
        'headline' => 'Ihre Karten sind unterwegs',
        'intro' => '**:quantity Karten** für **:restaurant** sind verschickt (Serie :batch).',
        'next' => 'Wenn das Paket da ist: In der App die Lieferung bestätigen (Karten zählen, eine Karte antippen). Erst dann können die Karten verkauft werden.',
    ],
    'reason' => 'Grund',
    'signature' => 'GiftCard Pro',
];
