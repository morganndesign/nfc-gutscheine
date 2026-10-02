<?php

declare(strict_types=1);

namespace Tests\Stress;

use App\Enums\RoleSlug;
use App\Enums\UserStatus;
use App\Exceptions\Domain\DomainException;
use App\Models\Restaurant;
use App\Models\User;
use App\Services\Users\UserService;
use App\Support\Actor;
use Database\Seeders\NotificationTemplateSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Database\Seeders\SystemSettingsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabaseState;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Throwable;

/**
 * Real concurrency on MySQL: owners who deactivate or demote each other at the same instant must never leave the
 * restaurant without an active owner (the last-owner check runs under a row lock). Runs only on MySQL.
 */
final class ConcurrentOwnerTest extends BaseTestCase
{
    private const OWNERS = 6;

    private Restaurant $restaurant;

    /** @var list<User> */
    private array $owners = [];

    private string $dir;

    protected function setUp(): void
    {
        parent::setUp();
        if (DB::connection()->getDriverName() !== 'mysql' || ! function_exists('pcntl_fork')) {
            $this->markTestSkipped('Needs MySQL and pcntl.');
        }
        $this->artisan('migrate:fresh');
        $this->seed([RolesAndPermissionsSeeder::class, NotificationTemplateSeeder::class, SystemSettingsSeeder::class]);
        RefreshDatabaseState::$migrated = false;

        $this->restaurant = Restaurant::factory()->create();
        for ($i = 0; $i < self::OWNERS; $i++) {
            $this->owners[] = User::factory()->forRestaurant($this->restaurant)->role(RoleSlug::Owner)->create();
        }
        $this->dir = sys_get_temp_dir().'/gcp-stress-'.Str::random(8);
        mkdir($this->dir);
    }

    protected function tearDown(): void
    {
        if (isset($this->dir) && is_dir($this->dir)) {
            array_map('unlink', glob($this->dir.'/*') ?: []);
            rmdir($this->dir);
        }
        parent::tearDown();
    }

    public function test_owners_deactivating_each_other_at_once_always_leave_one(): void
    {
        $this->race(fn (int $i): User => app(UserService::class)->deactivate(
            new Actor($this->owners[$i]->refresh()),
            $this->owners[($i + 1) % self::OWNERS]->refresh(),
        ));

        $this->assertGreaterThanOrEqual(1, $this->activeOwners());
    }

    public function test_owners_demoting_each_other_at_once_always_leave_one(): void
    {
        $this->race(fn (int $i): User => app(UserService::class)->update(
            new Actor($this->owners[$i]->refresh()),
            $this->owners[($i + 1) % self::OWNERS]->refresh(),
            ['role' => RoleSlug::Manager->value],
        ));

        $this->assertGreaterThanOrEqual(1, $this->activeOwners());
    }

    private function activeOwners(): int
    {
        return User::query()->where('restaurant_id', $this->restaurant->getKey())->where('status', UserStatus::Active->value)
            ->whereHas('role', static fn ($q) => $q->where('slug', RoleSlug::Owner->value))->count();
    }

    /** @return list<string> */
    private function race(\Closure $work): array
    {
        DB::disconnect();
        $go = $this->dir.'/go';
        $pids = [];
        for ($i = 0; $i < self::OWNERS; $i++) {
            $pid = pcntl_fork();
            if ($pid === 0) {
                try {
                    DB::reconnect();
                    DB::select('select 1');
                    while (! file_exists($go)) {
                        usleep(1000);
                    }
                    $work($i);
                    $result = 'ok';
                } catch (DomainException $e) {
                    $result = 'err:'.$e->errorCode();
                } catch (Throwable $e) {
                    $result = 'crash:'.$e::class.': '.$e->getMessage();
                }
                file_put_contents($this->dir."/r{$i}", $result);
                posix_kill(posix_getpid(), SIGKILL);
            }
            $pids[] = $pid;
        }
        usleep(200_000);
        touch($go);
        foreach ($pids as $pid) {
            pcntl_waitpid($pid, $status);
        }
        DB::reconnect();

        $results = [];
        for ($i = 0; $i < self::OWNERS; $i++) {
            $results[] = (string) @file_get_contents($this->dir."/r{$i}");
        }
        foreach ($results as $r) {
            $this->assertNotSame('', $r, 'a worker did not report');
            // A deadlock between two owner locks is retried by nobody here; MySQL picks a victim, which is fine.
            if (str_starts_with($r, 'crash:')) {
                $this->assertStringContainsString('Deadlock', $r);
            }
        }

        return $results;
    }
}
