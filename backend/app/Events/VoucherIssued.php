<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Voucher;
use App\Models\VoucherTransaction;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;
use SensitiveParameter;

final class VoucherIssued implements ShouldDispatchAfterCommit
{
    use Dispatchable;
    use SerializesModels;

    public function __construct(
        public readonly Voucher $voucher,
        public readonly VoucherTransaction $transaction,
        /** The printable QR of a digital voucher, while it exists in memory: e-mailed to the guest as a PDF. */
        #[SensitiveParameter] public readonly ?string $printablePayload = null,
    ) {}
}
