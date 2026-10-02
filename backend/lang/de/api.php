<?php

declare(strict_types=1);

// Messages of the API itself (validation outcomes decided in code).
return [
    'deactivated' => 'Dieses Konto wurde deaktiviert.',
    'credentials' => 'E-Mail-Adresse oder Passwort ist falsch. Nach zu vielen Versuchen wird das Konto für einige Minuten gesperrt.',
    'currency_locked' => 'Die Währung kann nicht mehr geändert werden, sobald Gutscheine ausgegeben wurden.',
    'confirm_slug' => 'Geben Sie zur Bestätigung den Kurznamen „:slug“ des Restaurants ein.',
    'invalid_link' => 'Dieser Link ist ungültig oder abgelaufen. Bitte fordern Sie einen neuen an.',
    'min_above_max' => 'Der Mindestwert eines Gutscheins darf das maximale Guthaben nicht übersteigen.',
    'debit_above_daily' => 'Das Limit pro Einlösung darf das Tageslimit pro Gutschein nicht übersteigen.',
    'logo_unreadable' => 'Das Bild konnte nicht gelesen werden. Laden Sie eine PNG- oder JPEG-Datei hoch.',
    'logo_too_small' => 'Das Logo muss mindestens :min Pixel breit und hoch sein.',
    'logo_too_large' => 'Das Logo darf höchstens :max Pixel breit und hoch sein.',
];
