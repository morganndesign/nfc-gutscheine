<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\GiftCard;
use App\Models\GiftCardTransaction;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

final class GiftCardIssued implements ShouldDispatchAfterCommit
{
    use Dispatchable;
    use SerializesModels;

    public function __construct(
        public readonly GiftCard $card,
        public readonly GiftCardTransaction $transaction,
    ) {}
}
