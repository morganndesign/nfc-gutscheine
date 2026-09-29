<?php

declare(strict_types=1);

namespace App\Listeners;

use App\Support\OpsAlert;
use Illuminate\Queue\Events\JobFailed;

/**
 * A job that failed for good (all retries used): a guest receipt, an invitation or a password link did not go out.
 * Operations hear of it at most once an hour per job type; the job stays in failed_jobs for `queue:retry`.
 */
final class AlertOnFailedJob
{
    public function handle(JobFailed $event): void
    {
        $name = $event->job->resolveName();

        OpsAlert::send(
            'job-failed:'.$name,
            "Background job failed: {$name}",
            "The job {$name} failed after all retries: ".mb_substr($event->exception->getMessage(), 0, 500)."\n\n"
            ."Check the worker's logs, fix the cause (often the mail server), then retry:\n"
            .'Terminal → api → php artisan queue:failed, php artisan queue:retry all',
            3600,
        );
    }
}
