<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\User;
use App\Services\Users\UserService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Facades\Password;

/**
 * "Forgot password", sent from the queue (audit F3): the HTTP request answers at once with the same text for
 * every address (S5), and a slow mail server never blocks a PHP worker.
 *
 * Accounts that never accepted their invitation get nothing: the invitation stays the only way in (S6).
 */
final class SendPasswordResetLink implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;

    public int $tries = 3;

    /** @var list<int> */
    public array $backoff = [30, 300];

    public function __construct(public readonly string $email) {}

    public function handle(): void
    {
        /** @var User|null $user */
        $user = User::query()->where('email', $this->email)->first();

        if ($user === null || ! $user->isActive() || UserService::isPendingInvitation($user)) {
            return;
        }

        Password::broker('users')->sendResetLink(['email' => $this->email]);
    }
}
