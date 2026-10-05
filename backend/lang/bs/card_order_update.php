<?php

declare(strict_types=1);

return [
    'accepted' => [
        'subject' => 'Narudžba kartica prihvaćena: :quantity kartica',
        'headline' => 'Vaša narudžba kartica je prihvaćena',
        'intro' => 'Narudžba **:quantity kartica** za **:restaurant** je prihvaćena (serija :batch). Kartice se sada izrađuju.',
        'next' => 'Čim kartice budu na putu, dobit ćete još jedan e-mail.',
    ],
    'declined' => [
        'subject' => 'Narudžba kartica odbijena: :quantity kartica',
        'headline' => 'Vaša narudžba kartica je odbijena',
        'intro' => 'Narudžba **:quantity kartica** za **:restaurant** je odbijena.',
        'next' => 'Ako imate pitanja, samo odgovorite na ovaj e-mail ili naručite ponovo u aplikaciji pod Kartice.',
    ],
    'shipped' => [
        'subject' => 'Vaše kartice su na putu: :quantity kartica',
        'headline' => 'Vaše kartice su na putu',
        'intro' => '**:quantity kartica** za **:restaurant** je poslano (serija :batch).',
        'next' => 'Kad paket stigne, potvrdite isporuku u aplikaciji (prebrojite kartice, prislonite jednu). Tek tada se kartice mogu prodavati.',
    ],
    'reason' => 'Razlog',
    'signature' => 'GiftCard Pro',
];
