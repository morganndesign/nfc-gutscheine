<?php

declare(strict_types=1);

namespace App\Data;

use App\Models\GiftCard;
use App\Models\GiftCardTransaction;

final readonly class TransactionResult
{
    public function __construct(
        public GiftCard $card,
        public GiftCardTransaction $transaction,
        /** True when an identical request (same idempotency key) was already processed and is being replayed. */
        public bool $replayed = false,
    ) {}
}
