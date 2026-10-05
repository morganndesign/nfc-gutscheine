<?php

declare(strict_types=1);

return [
    'accepted' => [
        'subject' => 'Card order accepted: :quantity cards',
        'headline' => 'Your card order is accepted',
        'intro' => 'The order of **:quantity cards** for **:restaurant** is accepted (batch :batch). The cards are now being made.',
        'next' => 'You will get another e-mail as soon as the cards are on their way.',
    ],
    'declined' => [
        'subject' => 'Card order declined: :quantity cards',
        'headline' => 'Your card order was declined',
        'intro' => 'The order of **:quantity cards** for **:restaurant** was declined.',
        'next' => 'If you have questions, just reply to this e-mail, or order again in the app under Cards.',
    ],
    'shipped' => [
        'subject' => 'Your cards are on their way: :quantity cards',
        'headline' => 'Your cards are on their way',
        'intro' => '**:quantity cards** for **:restaurant** have been shipped (batch :batch).',
        'next' => 'When the parcel arrives, confirm the delivery in the app (count the cards, tap one). Only then can the cards be sold.',
    ],
    'reason' => 'Reason',
    'signature' => 'GiftCard Pro',
];
