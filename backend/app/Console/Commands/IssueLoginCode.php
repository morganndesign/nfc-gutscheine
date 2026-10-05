<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Auth\LoginCodeService;
use App\Support\Actor;
use Illuminate\Console\Command;
use RuntimeException;

/**
 * Emergency path when e-mail does not work (audit S2): the person signs in with the password as usual (the code
 * cannot be e-mailed), then someone with access to the server runs this command within 10 minutes and passes the
 * printed code on. Recorded in the audit log.
 */
final class IssueLoginCode extends Command
{
    protected $signature = 'auth:login-code {email}';

    protected $description = 'Print a sign-in code for a person whose sign-in is waiting for its e-mailed code (when e-mail is down).';

    public function handle(LoginCodeService $codes, AuditLogger $audit): int
    {
        /** @var User|null $user */
        $user = User::query()->where('email', strtolower((string) $this->argument('email')))->first();
        if ($user === null || ! $user->isActive()) {
            $this->error('No active account with this e-mail address.');

            return self::FAILURE;
        }

        try {
            $code = $codes->codeForConsole($user);
        } catch (RuntimeException $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        $actor = Actor::system();
        $audit->log('auth.login_code_console', $actor, $user, restaurantId: $user->restaurant_id);

        $this->info('Sign-in code for '.$user->email.': '.chunk_split($code, 3, ' '));
        $this->line('Valid for the waiting sign-in only, for 10 minutes. Pass it on in person or by phone.');

        return self::SUCCESS;
    }
}
