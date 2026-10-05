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
    'logo_unreadable' => 'The image could not be read. Upload a PNG or JPEG file.',
    'logo_too_small' => 'The logo must be at least :min pixels wide and high.',
    'logo_too_large' => 'The logo may be at most :max pixels wide and high.',
    'login_code_wrong' => 'The code is not correct. Please check the latest e-mail.',
    'login_code_expired' => 'This code has expired or was entered wrongly too often. Please sign in again.',
    'login_code_wait' => 'Please wait :seconds seconds before asking for a new code.',
    'login_code_locked' => 'Too many wrong codes. The account is locked for 60 minutes.',
    'login_code_unsent' => 'The code could not be sent by e-mail. Please try again in a moment.',
];
