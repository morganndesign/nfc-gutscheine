<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\Security\SecurityEventSealer;
use Illuminate\Console\Command;

final class SealSecurityEvents extends Command
{
    protected $signature = 'giftcard:seal-security-events';

    protected $description = 'Hash-chain the security events that have settled into seals (runs every minute).';

    public function handle(SecurityEventSealer $sealer): int
    {
        $seals = $sealer->seal();
        SecurityEventSealer::logRun($seals);
        $this->info($seals === 0 ? 'Nothing to seal.' : "{$seals} seal(s) written.");

        return self::SUCCESS;
    }
}
