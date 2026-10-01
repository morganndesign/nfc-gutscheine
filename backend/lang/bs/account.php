<?php

declare(strict_types=1);

/*
 * E-mailovi o sigurnosti računa. Zamjene: :name (ime), :changed_by, :restaurant, :email.
 */
return [
    'email_changed' => [
        'subject' => 'Vaša e-mail adresa za prijavu u GiftCard Pro je promijenjena',
        'greeting' => 'Zdravo :name,',
        'body' => ':changed_by je promijenio/la e-mail adresu za prijavu na Vašem računu u „:restaurant“ na :email.',
        'signed_out' => 'Odjavljeni ste sa svih uređaja.',
        'unexpected' => 'Ako ovo niste očekivali, odmah se obratite vlasniku restorana.',
    ],
];
