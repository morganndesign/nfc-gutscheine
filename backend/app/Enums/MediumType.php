<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * How a voucher is presented (architecture §6.1). `nfc_card` (Phase 2) and `email_voucher` (Phase 7) are added
 * together with their flows.
 */
enum MediumType: string
{
    /** Static QR on paper or PDF: a 256-bit bearer secret, digital vouchers only, one active per voucher. */
    case PrintableQr = 'printable_qr';
}
