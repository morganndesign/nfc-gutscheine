<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\Security\SecurityMonitor;
use Illuminate\Console\Command;

final class MonitorSecurityEvents extends Command
{
    protected $signature = 'giftcard:monitor-security-events';

    protected $description = 'Run the fraud rules over new security events and raise alerts.';

    public function handle(SecurityMonitor $monitor): int
    {
        $this->info($monitor->run().' events checked.');

        return self::SUCCESS;
    }
}
