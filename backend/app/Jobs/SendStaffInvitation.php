<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\NotificationLog;
use App\Models\Restaurant;
use App\Models\User;
use App\Services\Users\InvitationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Throwable;

/**
 * Sends an invitation from the queue (audit F3). The token is created here, in the worker, so it never sits in
 * the queue payload; the outcome is written to the invitation's notification_logs row.
 */
final class SendStaffInvitation implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;

    public int $tries = 1;

    public function __construct(
        public readonly string $userId,
        public readonly string $restaurantId,
        public readonly ?string $invitedBy,
        public readonly string $logId,
    ) {
        $this->onQueue('notifications');
    }

    public function handle(InvitationService $invitations): void
    {
        $user = User::query()->find($this->userId);
        $restaurant = Restaurant::query()->withTrashed()->find($this->restaurantId);
        $log = NotificationLog::query()->find($this->logId);

        if ($user instanceof User && $restaurant instanceof Restaurant && $log instanceof NotificationLog) {
            $invitations->deliver($user, $restaurant, $this->invitedBy, $log);
        }
    }

    /**
     * The job died with its worker (killed, out of memory, container restart) and is not tried again (one try: every
     * attempt makes a new link). Without this the invitation would show "queued" for ever; "failed" lets the owner
     * send it again.
     */
    public function failed(Throwable $e): void
    {
        NotificationLog::query()->whereKey($this->logId)->where('status', 'queued')
            ->update(['status' => 'failed', 'error' => mb_substr($e->getMessage(), 0, 1000)]);
    }
}
