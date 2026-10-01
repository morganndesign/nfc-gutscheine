<?php

declare(strict_types=1);

/*
 * E-mail s pozivnicom (novi račun: vlasnik restorana ili osoblje).
 * Zamjene: :name (ime), :restaurant, :inviter, :email (adresa podrške).
 */
return [
    'subject' => 'Vaša pozivnica za GiftCard Pro',
    'headline' => 'Pozvani ste u GiftCard Pro.',
    'greeting' => 'Zdravo :name,',

    'body_owner' => 'Pozvani ste u GiftCard Pro kao vlasnik restorana „:restaurant“.',
    'body_staff' => ':inviter Vas je pozvao/la da upravljate poklon karticama za restoran „:restaurant“ putem GiftCard Pro.',
    'body_staff_anonymous' => 'Pozvani ste da upravljate poklon karticama za restoran „:restaurant“ putem GiftCard Pro.',
    'instruction' => 'Kliknite na dugme ispod da postavite lozinku i aktivirate svoj račun.',

    'action' => 'Postavite lozinku',
    'expiry' => 'Ovaj link važi 72 sata i može se iskoristiti samo jednom.',

    'support' => 'Ako je link istekao ili Vam treba pomoć, kontaktirajte nas na:',
    'support_staff' => 'Ako je link istekao, zamolite menadžera restorana da Vam ponovo pošalje pozivnicu.',

    'closing' => 'Hvala,',
    'signature' => 'Vaš GiftCard Pro tim',
];
