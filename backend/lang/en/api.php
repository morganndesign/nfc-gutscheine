<?php

declare(strict_types=1);

// Messages of the API itself (validation outcomes decided in code).
return [
    'deactivated' => 'This account has been deactivated.',
    'credentials' => 'The e-mail address or password is incorrect. After too many attempts the account is locked for a few minutes.',
    'currency_locked' => 'The currency cannot be changed after vouchers were issued.',
    'confirm_slug' => "Type the restaurant's short name \":slug\" to confirm.",
    'invalid_link' => 'This link is invalid or has expired. Please request a new one.',
    'min_above_max' => 'The minimum voucher value must not exceed the maximum voucher balance.',
    'debit_above_daily' => 'The limit per redemption must not exceed the daily limit per voucher.',
];
