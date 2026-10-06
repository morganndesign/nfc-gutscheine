<?php

declare(strict_types=1);

return [
    'product' => 'Vaučer – :restaurant',
    'max_amount' => 'Najveći iznos mora biti između :min i :max centi.',
    'amounts' => 'Svaki iznos mora biti između :min i :max centi.',
    'not_connected' => 'Prvo povežite Stripe račun i sačekajte da ga Stripe odobri.',
    'legal_missing' => 'Za online prodaju prodavnici trebaju linkovi na AGB i impressum restorana.',
    'mail' => [
        'signature' => 'Vaš GiftCard Pro tim',
        'dispute' => [
            'subject' => 'Online plaćanje reklamirano: vaučer :voucher blokiran',
            'headline' => 'Online plaćanje je reklamirano',
            'intro' => 'Vlasnik kartice je reklamirao plaćanje od **:amount** za online vaučer restorana **:restaurant** (vaučer :voucher). Vaučer je blokiran i više ne može plaćati.',
            'next' => 'Odgovorite na reklamaciju u svom Stripe dashboardu. Ako bude povučena, vaučer možete ponovo deblokirati u dashboardu.',
        ],
        'refunded_elsewhere' => [
            'subject' => 'Refundirano u Stripeu: vaučer :voucher blokiran',
            'headline' => 'Online plaćanje je refundirano u Stripeu',
            'intro' => 'Za online vaučer :voucher restorana **:restaurant** (**:amount**) novac je vraćen direktno u Stripeu. Vaučer je zato blokiran.',
            'next' => 'Provjerite vaučer u dashboardu i refundirajte ga ili ponovo deblokirajte.',
        ],
    ],
];
