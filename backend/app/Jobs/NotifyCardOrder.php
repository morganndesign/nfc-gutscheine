<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\RoleSlug;
use App\Models\CardOrder;
use App\Models\User;
use App\Notifications\CardOrderNotification;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;

/** Tells the platform staff that a restaurant ordered cards, in each admin's language ({@see CardOrderNotification}). */
final class NotifyCardOrder implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;

    public int $tries = 5;

    /** @var list<int> */
    public array $backoff = [30, 120, 600, 1800];

    public function __construct(public readonly string $orderId)
    {
        $this->onQueue('notifications');
    }

    public function handle(): void
    {
        /** @var CardOrder|null $order */
        $order = CardOrder::query()->withoutGlobalScopes()->with(['restaurant', 'requester'])->find($this->orderId);
        if ($order === null) {
            return;
        }
        $admins = User::query()->withoutGlobalScopes()
            ->whereHas('role', static fn ($q) => $q->where('slug', RoleSlug::PlatformAdmin->value))
            ->get()
            ->filter(static fn (User $u): bool => $u->isActive());

        foreach ($admins as $admin) {
            $language = match (strtolower(substr((string) $admin->locale, 0, 2))) {
                'en' => 'en',
                'bs', 'hr', 'sr' => 'bs',
                default => 'de',
            };
            $admin->notify((new CardOrderNotification($order))->locale($language));
        }
    }
}
