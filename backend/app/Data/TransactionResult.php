<?php

declare(strict_types=1);

namespace App\Data;

use App\Models\Voucher;
use App\Models\VoucherTransaction;

final readonly class TransactionResult
{
    public function __construct(
        public Voucher $voucher,
        public VoucherTransaction $transaction,
        /** True when an identical request (same idempotency key) was already processed and is being replayed. */
        public bool $replayed = false,
    ) {}
}
