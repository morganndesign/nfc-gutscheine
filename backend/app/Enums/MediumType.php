<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * How a voucher is presented (architecture §6.1). `email_voucher` is added with its flow (Phase 7).
 */
enum MediumType: string
{
    /** Static QR on paper or PDF: a 256-bit bearer secret, digital vouchers only, one active per voucher. */
    case PrintableQr = 'printable_qr';

    /** A physical NTAG 424 DNA card (`media.card_id`); its effective status is the card's lifecycle state. */
    case NfcCard = 'nfc_card';
}
