<?php

declare(strict_types=1);

/*
 * E-Mails zur Kontosicherheit. Platzhalter: :name (Vorname), :changed_by, :restaurant, :email.
 */
return [
    'email_changed' => [
        'subject' => 'Ihre Anmelde-E-Mail bei GiftCard Pro wurde geändert',
        'greeting' => 'Hallo :name,',
        'body' => ':changed_by hat die Anmelde-E-Mail Ihres Kontos bei „:restaurant“ auf :email geändert.',
        'signed_out' => 'Sie wurden auf allen Geräten abgemeldet.',
        'unexpected' => 'Falls Sie das nicht erwartet haben, wenden Sie sich bitte sofort an den Inhaber des Lokals.',
    ],
];
