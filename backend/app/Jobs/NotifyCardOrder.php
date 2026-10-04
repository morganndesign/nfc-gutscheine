<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Enums\RoleSlug;
use App\Models\CardOrder;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Facades\Mail;

/** Tells the platform staff that a restaurant ordered cards, in each admin's language. */
final class NotifyCardOrder implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;

    public int $tries = 5;

    /** @var list<int> */
    public array $backoff = [30, 120, 600, 1800];

    /** @var array<'de'|'en'|'bs', array{subject: string, body: string, note: string, by: string}> */
    private const TEXT = [
        'de' => [
            'subject' => 'Kartenbestellung: :restaurant · :quantity Karten',
            'body' => ':restaurant bestellt :quantity Karten.',
            'note' => 'Notiz',
            'by' => 'Bestellt von',
        ],
        'en' => [
            'subject' => 'Card order: :restaurant · :quantity cards',
            'body' => ':restaurant orders :quantity cards.',
            'note' => 'Note',
            'by' => 'Ordered by',
        ],
        'bs' => [
            'subject' => 'Narudžba kartica: :restaurant · :quantity kartica',
            'body' => ':restaurant naručuje :quantity kartica.',
            'note' => 'Napomena',
            'by' => 'Naručio/la',
        ],
    ];

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
            $t = self::TEXT[match (strtolower(substr((string) $admin->locale, 0, 2))) {
                'en' => 'en',
                'bs', 'hr', 'sr' => 'bs',
                default => 'de',
            }];
            $replace = [':restaurant' => $order->restaurant->name, ':quantity' => (string) $order->quantity];
            $lines = [strtr($t['body'], $replace)];
            if ($order->note !== null) {
                $lines[] = $t['note'].': '.$order->note;
            }
            if ($order->requester !== null) {
                $lines[] = $t['by'].': '.$order->requester->name;
            }
            $lines[] = '';
            $lines[] = config('giftcard.frontend_url').'/admin/card-batches';

            Mail::raw(implode("\n", $lines), static fn ($message) => $message->to($admin->email)->subject('[GiftCard Pro] '.strtr($t['subject'], $replace)));
        }
    }
}
