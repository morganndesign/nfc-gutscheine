<?php

declare(strict_types=1);

return [
    /*
    |--------------------------------------------------------------------------
    | Public card URL
    |--------------------------------------------------------------------------
    | The URL written to NFC tags and encoded in QR codes is
    | "{card_base_url}/c/{public_token}". It must point at the frontend so that
    | phones opening the link natively (iOS background tag reading, camera QR
    | scans) land in the waiter app or the public balance page.
    */
    'card_base_url' => rtrim((string) env('CARD_BASE_URL', env('FRONTEND_URL', 'http://localhost:3000')), '/'),

    'frontend_url' => rtrim((string) env('FRONTEND_URL', 'http://localhost:3000'), '/'),

    'card_number' => [
        // Total digits including the Luhn check digit.
        'length' => 16,
        'max_generation_attempts' => 10,
    ],

    'security' => [
        // Failed card lookups (not found / foreign) allowed per user or IP before throttling.
        'scan_failure_limit' => (int) env('SCAN_FAILURE_LIMIT', 10),
        'scan_failure_decay_seconds' => (int) env('SCAN_FAILURE_DECAY', 300),
        // Consecutive failed logins before the account is temporarily locked.
        'login_lockout_threshold' => (int) env('LOGIN_LOCKOUT_THRESHOLD', 10),
        'login_lockout_minutes' => (int) env('LOGIN_LOCKOUT_MINUTES', 15),
        // Maximum lifetime of API tokens in days (null = never expires).
        'api_token_max_days' => env('API_TOKEN_MAX_DAYS') === null || env('API_TOKEN_MAX_DAYS') === '' ? 365 : (int) env('API_TOKEN_MAX_DAYS'),
        // Sign-in tokens of the native waiter app: rolling lifetime in days, renewed while the phone is in use.
        'device_token_days' => (int) env('DEVICE_TOKEN_DAYS', 30),
        'idempotency_key_max_length' => 96,
    ],

    'nfc' => [
        'ntag424' => [
            // AES-128 keys (32 hex chars). The meta-read key decrypts PICCData (UID + read counter);
            // the file-read key is the SDM MAC master key. Both MUST be set to unique secrets in production.
            'meta_read_key' => env('NTAG424_META_READ_KEY'),
            'file_read_key' => env('NTAG424_FILE_READ_KEY'),
            // When true, the per-tag MAC key = first 16 bytes of HMAC-SHA256(file_read_key, UID).
            'diversify_keys' => (bool) env('NTAG424_DIVERSIFY_KEYS', true),
        ],
    ],

    'notifications' => [
        'expiring_days_before' => (int) env('CARD_EXPIRING_NOTICE_DAYS', 30),
        'low_balance_threshold' => (int) env('CARD_LOW_BALANCE_THRESHOLD', 500),
    ],

    // Seed the demo restaurant outside local/staging (never in production).
    'seed_demo_data' => (bool) env('SEED_DEMO_DATA', false),

    // Timezone in which nightly jobs (expiration, reminders) are scheduled.
    'schedule_timezone' => env('SCHEDULE_TIMEZONE', 'Europe/Vienna'),

    // Operations alerts (e.g. a queue backlog found by queue:monitor). Empty = the platform support e-mail.
    'ops_alert_email' => env('OPS_ALERT_EMAIL'),

    // Language of account e-mails (invitations). The restaurant's language is used when a translation exists
    // (restaurant locale de-AT → de, en-GB → en); otherwise this platform default. Texts: lang/<locale>/invitation.php.
    'mail_locale' => env('MAIL_LOCALE', 'de'),
    'mail_locales' => ['de', 'en'],

    // "Send test e-mail": refuse a recipient whose domain has no mail server (MX/A record) before trying.
    'verify_mail_domains' => (bool) env('MAIL_VERIFY_DOMAINS', true),

    'exports' => [
        'chunk_size' => 1000,
    ],
];
