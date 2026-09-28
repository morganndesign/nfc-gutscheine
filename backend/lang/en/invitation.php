<?php

declare(strict_types=1);

/*
 * Invitation e-mail (new account: restaurant owner or staff).
 * Placeholders: :name (first name), :restaurant, :inviter, :email (support address).
 */
return [
    'subject' => 'Your invitation to GiftCard Pro',
    'headline' => 'You have been invited to GiftCard Pro.',
    'greeting' => 'Hello :name,',

    'body_owner' => 'You have been invited to GiftCard Pro as the owner of the restaurant “:restaurant”.',
    'body_staff' => ':inviter has invited you to manage gift cards for the restaurant “:restaurant” with GiftCard Pro.',
    'body_staff_anonymous' => 'You have been invited to manage gift cards for the restaurant “:restaurant” with GiftCard Pro.',
    'instruction' => 'Please click the button below to set your password and activate your account.',

    'action' => 'Set your password',
    'expiry' => 'This link is valid for 72 hours and can only be used once.',

    'support' => 'If the link has expired or you need help, please contact us at:',
    'support_staff' => 'If the link has expired, please ask your restaurant manager to send the invitation again.',

    'closing' => 'Thank you,',
    'signature' => 'Your GiftCard Pro team',
];
