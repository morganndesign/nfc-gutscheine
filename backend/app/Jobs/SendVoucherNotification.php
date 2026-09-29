<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\Voucher;
use App\Services\Notifications\VoucherNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

final class SendVoucherNotification implements ShouldBeUnique, ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 5;

    /** @var list<int> */
    public array $backoff = [30, 120, 600, 1800];

    public function __construct(
        public readonly string $voucherId,
        public readonly string $templateKey,
        /** The sale or reload the e-mail confirms; null for reminders. */
        public readonly ?string $transactionId = null,
    ) {
        $this->onQueue('notifications');
    }

    public function uniqueId(): string
    {
        return $this->voucherId.':'.$this->templateKey.':'.($this->transactionId ?? '');
    }

    public function handle(VoucherNotificationService $notifications): void
    {
        /** @var Voucher|null $voucher */
        $voucher = Voucher::query()->withoutGlobalScopes()->find($this->voucherId);

        if ($voucher !== null) {
            $notifications->send($voucher, $this->templateKey, $this->transactionId);
        }
    }
}
