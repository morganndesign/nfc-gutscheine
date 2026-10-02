<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Queue\Failed\FailedJobProviderInterface;
use RuntimeException;
use Tests\TestCase;

/** Operations list, retry and forget failed jobs with the documented commands (docs/DOCKER.md). */
final class FailedJobsTest extends TestCase
{
    public function test_failed_jobs_can_be_listed_and_forgotten(): void
    {
        config(['queue.failed.driver' => 'database-uuids', 'queue.failed.database' => config('database.default')]);
        $failer = $this->app->make('queue.failer');
        $this->assertInstanceOf(FailedJobProviderInterface::class, $failer);
        $uuid = '0198f0c2-0000-7000-8000-000000000001';
        $failer->log('redis', 'notifications', json_encode(['uuid' => $uuid, 'displayName' => 'App\\Jobs\\SendVoucherNotification']) ?: '', new RuntimeException('SMTP down'));

        $this->assertSame([$uuid], $failer->ids());
        $this->artisan('queue:failed')->assertSuccessful()->expectsOutputToContain($uuid);
        $this->artisan('queue:forget', ['id' => $uuid])->assertSuccessful();
        $this->assertSame([], $failer->ids());
    }
}
