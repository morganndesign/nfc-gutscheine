<?php

declare(strict_types=1);

/*
 * Account security e-mails. Placeholders: :name (first name), :changed_by, :restaurant, :email.
 */
return [
    'email_changed' => [
        'subject' => 'Your GiftCard Pro sign-in e-mail was changed',
        'greeting' => 'Hello :name,',
        'body' => ':changed_by changed the sign-in e-mail of your account at “:restaurant” to :email.',
        'signed_out' => 'You have been signed out on all devices.',
        'unexpected' => 'If you did not expect this, contact the owner of the restaurant right away.',
    ],
];
