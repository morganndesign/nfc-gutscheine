<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\Voucher;
use App\Services\Notifications\VoucherNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeEncrypted;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use SensitiveParameter;

/**
 * Encrypted on the queue: a sale's job carries the voucher's printable QR, which is as good as cash.
 */
final class SendVoucherNotification implements ShouldBeEncrypted, ShouldBeUnique, ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 5;

    /** @var list<int> */
    public array $backoff = [30, 120, 600, 1800];

    /**
     * The unique lock outlives every retry (about 45 minutes) but not a day: a job lost from the queue (Redis data
     * loss, a cleared queue) never released its lock, and without an expiry the voucher's reminder could never be
     * queued again. The daily reminder run then simply queues it once more.
     */
    public int $uniqueFor = 43200;

    public function __construct(
        public readonly string $voucherId,
        public readonly string $templateKey,
        /** The sale or reload the e-mail confirms; null for reminders. */
        public readonly ?string $transactionId = null,
        /** A digital voucher's QR, attached as a PDF to the sale's e-mail. */
        #[SensitiveParameter] public readonly ?string $printablePayload = null,
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
            $notifications->send($voucher, $this->templateKey, $this->transactionId, $this->printablePayload);
        }
    }
}
