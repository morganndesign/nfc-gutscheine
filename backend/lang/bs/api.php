<?php

declare(strict_types=1);

// Messages of the API itself (validation outcomes decided in code).
return [
    'deactivated' => 'Ovaj nalog je deaktiviran.',
    'credentials' => 'E-mail adresa ili lozinka nije tačna. Nakon previše pokušaja nalog se zaključava na nekoliko minuta.',
    'currency_locked' => 'Valuta se ne može promijeniti nakon što su izdani vaučeri.',
    'confirm_slug' => 'Za potvrdu upišite kratko ime restorana „:slug“.',
    'invalid_link' => 'Ovaj link nije važeći ili je istekao. Zatražite novi.',
    'min_above_max' => 'Najmanja vrijednost vaučera ne smije biti veća od najvećeg stanja.',
    'debit_above_daily' => 'Limit po naplati ne smije biti veći od dnevnog limita po vaučeru.',
    'logo_unreadable' => 'Slika se ne može pročitati. Učitajte PNG ili JPEG datoteku.',
    'logo_too_small' => 'Logo mora biti najmanje :min piksela širok i visok.',
];
