<?php

declare(strict_types=1);

namespace App\Data;

use App\Models\Payment;
use App\Models\Voucher;
use App\Models\VoucherTransaction;

final readonly class SaleResult
{
    public function __construct(
        public Voucher $voucher,
        public VoucherTransaction $transaction,
        public Payment $payment,
        /** The printable QR; null on a replay that may no longer show it (see VoucherService::sell()). */
        public ?PrintableSecret $printable,
        public bool $replayed = false,
    ) {}
}
