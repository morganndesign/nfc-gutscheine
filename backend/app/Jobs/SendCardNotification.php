<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\GiftCard;
use App\Services\Notifications\CardNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

final class SendCardNotification implements ShouldBeUnique, ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 5;

    /** @var list<int> */
    public array $backoff = [30, 120, 600, 1800];

    /** @param array<string, string> $extra */
    public function __construct(
        public readonly string $giftCardId,
        public readonly string $templateKey,
        public readonly array $extra = [],
        public readonly ?string $uniqueSuffix = null,
    ) {
        $this->onQueue('notifications');
    }

    public function uniqueId(): string
    {
        return $this->giftCardId.':'.$this->templateKey.':'.($this->uniqueSuffix ?? '');
    }

    public function handle(CardNotificationService $notifications): void
    {
        /** @var GiftCard|null $card */
        $card = GiftCard::query()->withoutGlobalScopes()->find($this->giftCardId);

        if ($card !== null) {
            $notifications->send($card, $this->templateKey, $this->extra);
        }
    }
}
