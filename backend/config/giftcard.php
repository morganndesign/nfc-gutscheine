<?php

declare(strict_types=1);
use App\Crypto\Ntag424\OriginalitySignature;

return [
    'frontend_url' => rtrim((string) env('FRONTEND_URL', 'http://localhost:3000'), '/'),

    'online' => [
        // Largest voucher a shop may sell online, in cents (decision 2026-10-06: 250 €); a shop may set less.
        'max_amount' => (int) env('ONLINE_MAX_AMOUNT', 25000),
        // GiftCard Pro's fee per online sale, in basis points of the amount (0 = none; decision pending).
        'application_fee_bps' => (int) env('ONLINE_APPLICATION_FEE_BPS', 0),
        // A card is bound to an online voucher no sooner than this after the payment (stolen-card purchases).
        'card_pickup_after_hours' => (int) env('ONLINE_CARD_PICKUP_AFTER_HOURS', 24),
        // Orders a single buyer (e-mail) or address may start per hour.
        'orders_per_hour' => (int) env('ONLINE_ORDERS_PER_HOUR', 5),
        // How long the payment page stays open (the provider's minimum is 30 minutes).
        'checkout_minutes' => 30,
    ],

    'fraud' => [
        // Reads of a card between two verified taps above which the card is flagged (read elsewhere, skimming).
        'counter_gap' => (int) env('FRAUD_COUNTER_GAP', 50),
    ],

    'cards' => [
        // NXP's public key for the NTAG 424 DNA originality signature (AN12196). Only genuine chips are keyed.
        'originality_public_key' => OriginalitySignature::NXP_PUBLIC_KEY,
    ],

    // Written into every card at the station: {tap_url}/{key set}?e=…&m=… opens the guest page (route /t/{key set}).
    // PERMANENT once the first card is personalised — a card cannot be rewritten in the restaurant. Choose the
    // domain for the life of the cards (a dedicated host such as https://t.example.at/t, routed to the gateway).
    // Only URLs of this origin are accepted from a tapped card.
    'tap_url' => rtrim((string) (env('TAP_URL') ?: rtrim((string) env('APP_URL', 'http://localhost'), '/').'/t'), '/'),

    'voucher_number' => [
        // Total digits including the Luhn check digit.
        'length' => 16,
        'max_generation_attempts' => 10,
    ],

    'security' => [
        // Presentments (architecture §10.1): lifetime of a verified presentment, and failed presentments allowed
        // per restaurant, user and device before a short lockout (audit S7: never per IP).
        'presentment_lifetime_seconds' => 60,
        'presentment_failure_limit' => (int) env('PRESENTMENT_FAILURE_LIMIT', 10),
        'presentment_failure_decay_seconds' => (int) env('PRESENTMENT_FAILURE_DECAY', 300),
        // A retried sale (same idempotency key, user and device) may show a fresh printable QR within this window.
        'sale_replay_window_minutes' => 15,
        // Consecutive failed logins before the account is temporarily locked.
        'login_lockout_threshold' => (int) env('LOGIN_LOCKOUT_THRESHOLD', 10),
        'login_lockout_minutes' => (int) env('LOGIN_LOCKOUT_MINUTES', 15),
        // Dashboard sign-in code by e-mail (decision 2026-10-05): lifetime, wrong tries, resends, and how long a
        // browser that confirmed a code is trusted.
        'login_code_minutes' => 10,
        'login_code_attempts' => 5,
        // Wrong codes of one person within an hour (across sign-ins) that lock the account: guessing with a stolen
        // password from many addresses ends there.
        'login_code_hourly_attempts' => 15,
        'login_code_lock_minutes' => 60,
        'login_code_sends' => 4,
        'login_code_resend_seconds' => 30,
        'trusted_browser_days' => 15,
        // Maximum lifetime of API tokens in days (null = never expires).
        'api_token_max_days' => env('API_TOKEN_MAX_DAYS') === null || env('API_TOKEN_MAX_DAYS') === '' ? 365 : (int) env('API_TOKEN_MAX_DAYS'),
        // Sign-in tokens of the native waiter app: rolling lifetime in days, renewed while the phone is in use.
        'device_token_days' => (int) env('DEVICE_TOKEN_DAYS', 30),
        'idempotency_key_max_length' => 96,
    ],

    // Platform ceilings for the restaurant limits (architecture §6.3, R22), in minor units.
    'limits' => [
        'max_voucher_balance' => (int) env('LIMIT_MAX_VOUCHER_BALANCE', 50000),
        'max_debit_per_transaction' => (int) env('LIMIT_MAX_DEBIT_PER_TRANSACTION', 25000),
        'max_debit_per_voucher_per_day' => (int) env('LIMIT_MAX_DEBIT_PER_VOUCHER_PER_DAY', 50000),
        // A voucher validity, when a restaurant sets one, is at least three years (audit P6).
        'min_validity_months' => 36,
    ],

    'notifications' => [
        'expiring_days_before' => (int) env('VOUCHER_EXPIRING_NOTICE_DAYS', 30),
    ],

    // Seed the demo restaurant outside local/staging (never in production).
    'seed_demo_data' => (bool) env('SEED_DEMO_DATA', false),

    // Timezone in which nightly jobs (expiration, reminders) are scheduled.
    'schedule_timezone' => env('SCHEDULE_TIMEZONE', 'Europe/Vienna'),

    // Operations alerts (e.g. a queue backlog found by queue:monitor). Empty = the platform support e-mail.
    'ops_alert_email' => env('OPS_ALERT_EMAIL'),

    // The backup volume as the scheduler sees it (read-only) and whether the offsite service copies it away.
    'backups' => [
        'dir' => env('BACKUP_DIR', ''),
        'offsite_enabled' => (bool) env('OFFSITE_ENABLED', false),
    ],

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
