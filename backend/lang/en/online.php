<?php

declare(strict_types=1);

return [
    'product' => 'Voucher – :restaurant',
    'max_amount' => 'The highest amount must be between :min and :max cents.',
    'amounts' => 'Every amount must be between :min and :max cents.',
    'not_connected' => 'Connect the Stripe account first and wait until Stripe enables it.',
    'legal_missing' => 'To sell online, the shop needs links to the restaurant\'s terms and imprint.',
    'mail' => [
        'signature' => 'Your GiftCard Pro team',
        'dispute' => [
            'subject' => 'Online payment disputed: voucher :voucher blocked',
            'headline' => 'An online payment was disputed',
            'intro' => 'The card holder disputed the payment of **:amount** for an online voucher of **:restaurant** (voucher :voucher). The voucher is blocked and can no longer pay.',
            'next' => 'Please answer the dispute in your Stripe dashboard. If it is withdrawn, you can unblock the voucher in the dashboard.',
        ],
        'refunded_elsewhere' => [
            'subject' => 'Refunded in Stripe: voucher :voucher blocked',
            'headline' => 'An online payment was refunded in Stripe',
            'intro' => 'Money for the online voucher :voucher of **:restaurant** (**:amount**) was paid back directly in Stripe. The voucher is therefore blocked.',
            'next' => 'Please check the voucher in the dashboard and refund it or unblock it.',
        ],
    ],
];
