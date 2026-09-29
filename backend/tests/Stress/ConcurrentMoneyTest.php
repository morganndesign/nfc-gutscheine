<?php

declare(strict_types=1);

namespace Tests\Stress;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Enums\CardState;
use App\Enums\PaymentMethod;
use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Enums\RoleSlug;
use App\Enums\TransactionType;
use App\Exceptions\Domain\DomainException;
use App\Models\Payment;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Presentments\PresentmentService;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Database\Seeders\NotificationTemplateSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Database\Seeders\SystemSettingsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabaseState;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\Support\WithCards;
use Throwable;

/**
 * Real concurrency on MySQL: separate processes (each with its own database connection) hit the same voucher at the
 * same instant. Row locks, UNIQUE keys and the hash chains must hold — no overdraft, no double booking, no broken
 * chain. Runs only on MySQL (CI "Tests (MySQL)"); the data is committed, so the schema is rebuilt around it.
 */
final class ConcurrentMoneyTest extends BaseTestCase
{
    use WithCards;

    private const WORKERS = 12;

    private Restaurant $restaurant;

    private User $manager;

    private string $dir;

    protected function setUp(): void
    {
        parent::setUp();
        if (DB::connection()->getDriverName() !== 'mysql' || ! function_exists('pcntl_fork')) {
            $this->markTestSkipped('Needs MySQL and pcntl.');
        }
        $this->artisan('migrate:fresh');
        $this->seed([RolesAndPermissionsSeeder::class, NotificationTemplateSeeder::class, SystemSettingsSeeder::class]);
        // Later tests in this process must not trust the schema of this one.
        RefreshDatabaseState::$migrated = false;

        $this->restaurant = Restaurant::factory()->create()->load('settings');
        // Velocity is not what is under test here.
        $this->restaurant->settings->forceFill(['max_redemptions_per_voucher_per_hour' => 0])->save();
        $this->manager = User::factory()->forRestaurant($this->restaurant)->role(RoleSlug::Manager)->create();
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

    public function test_simultaneous_redemptions_never_overdraw(): void
    {
        $voucher = $this->sellVoucher(5000);
        $presentments = array_map(fn (): string => $this->presentment($voucher), range(1, self::WORKERS));

        $results = $this->race(fn (int $i): string => $this->tenant(fn (): string => app(VoucherService::class)
            ->redeem($this->actor(), $voucher, 1000, $presentments[$i], (string) Str::uuid())->transaction->getKey()));

        $this->assertCount(5, array_filter($results, static fn (string $r): bool => str_starts_with($r, 'ok:')), implode(', ', $results));
        $this->assertSame(self::WORKERS - 5, count(array_filter($results, static fn (string $r): bool => $r === 'err:INSUFFICIENT_BALANCE')), implode(', ', $results));
        $this->assertSame(0, Voucher::query()->withoutGlobalScopes()->findOrFail($voucher->getKey())->balance);
        $this->assertIntact($voucher);
    }

    public function test_one_idempotency_key_books_once(): void
    {
        $voucher = $this->sellVoucher(5000);
        $presentments = array_map(fn (): string => $this->presentment($voucher), range(1, self::WORKERS));
        $key = (string) Str::uuid();

        $results = $this->race(fn (int $i): string => $this->tenant(fn (): string => app(VoucherService::class)
            ->redeem($this->actor(), $voucher, 700, $presentments[$i], $key)->transaction->getKey()));

        $ids = array_unique(array_filter(array_map(static fn (string $r): ?string => str_starts_with($r, 'ok:') ? substr($r, 3) : null, $results)));
        $this->assertCount(1, $ids, 'every retry answers with the one booking: '.implode(', ', $results));
        $this->assertSame(1, VoucherTransaction::query()->withoutGlobalScopes()->where('voucher_id', $voucher->getKey())->where('type', TransactionType::Redemption->value)->count());
        $this->assertSame(4300, Voucher::query()->withoutGlobalScopes()->findOrFail($voucher->getKey())->balance);
        $this->assertIntact($voucher);
    }

    public function test_one_presentment_pays_once(): void
    {
        $voucher = $this->sellVoucher(5000);
        $presentment = $this->presentment($voucher);

        $results = $this->race(fn (int $i): string => $this->tenant(fn (): string => app(VoucherService::class)
            ->redeem($this->actor(), $voucher, 300, $presentment, (string) Str::uuid())->transaction->getKey()));

        $this->assertCount(1, array_filter($results, static fn (string $r): bool => str_starts_with($r, 'ok:')), implode(', ', $results));
        $this->assertSame(4700, Voucher::query()->withoutGlobalScopes()->findOrFail($voucher->getKey())->balance);
        $this->assertIntact($voucher);
    }

    public function test_a_redemption_is_reversed_once(): void
    {
        $voucher = $this->sellVoucher(5000);
        $booked = $this->tenant(fn () => app(VoucherService::class)->redeem($this->actor(), $voucher, 2000, $this->presentment($voucher), (string) Str::uuid()));

        $results = $this->race(fn (int $i): string => $this->tenant(fn (): string => app(VoucherService::class)
            ->reverse($this->actor(), $booked->transaction->refresh(), 'stress')->transaction->getKey()));

        $this->assertCount(1, array_filter($results, static fn (string $r): bool => str_starts_with($r, 'ok:')), implode(', ', $results));
        $this->assertSame(5000, Voucher::query()->withoutGlobalScopes()->findOrFail($voucher->getKey())->balance);
        $this->assertIntact($voucher);
    }

    public function test_mixed_reloads_and_redemptions_keep_the_books_exact(): void
    {
        $voucher = $this->sellVoucher(10000);
        $presentments = array_map(fn (): string => $this->presentment($voucher), range(1, self::WORKERS));

        $results = $this->race(fn (int $i): string => $this->tenant(fn (): string => $i % 2 === 0
            ? app(VoucherService::class)->reload($this->actor(), $voucher, 1500, new PaymentData(PaymentMethod::Cash), (string) Str::uuid())->transaction->getKey()
            : app(VoucherService::class)->redeem($this->actor(), $voucher, 2500, $presentments[$i], (string) Str::uuid())->transaction->getKey()));

        $this->assertCount(self::WORKERS, array_filter($results, static fn (string $r): bool => str_starts_with($r, 'ok:')), implode(', ', $results));
        $this->assertSame(10000 + 6 * 1500 - 6 * 2500, Voucher::query()->withoutGlobalScopes()->findOrFail($voucher->getKey())->balance);
        $this->assertIntact($voucher);
    }

    public function test_one_card_is_sold_once_however_many_tills_try(): void
    {
        $this->setUpCardKeystore();
        try {
            $card = $this->availableCard($this->restaurant);
            Sanctum::actingAs($this->manager, ['*']);
            $chip = $this->chip($card);
            $presentments = array_map(fn (): string => (string) $this->tapCard($chip, 'bind')->assertCreated()->json('data.id'), range(1, self::WORKERS));

            $results = $this->race(fn (int $i): string => $this->tenant(fn (): string => app(VoucherService::class)->sell($this->actor(), new IssueVoucherData(
                value: 4000,
                payment: new PaymentData(PaymentMethod::Cash),
                idempotencyKey: (string) Str::uuid(),
                cardPresentmentId: $presentments[$i],
            ))->voucher->getKey()));
        } finally {
            $this->tearDownCardKeystore();
        }

        $this->assertCount(1, array_filter($results, static fn (string $r): bool => str_starts_with($r, 'ok:')), implode(', ', $results));
        $this->assertSame(self::WORKERS - 1, count(array_filter($results, static fn (string $r): bool => $r === 'err:PRESENTMENT_INVALID')), implode(', ', $results));
        // The refused sales left nothing behind: one voucher, one payment, one active card.
        $this->assertSame(1, Voucher::query()->withoutGlobalScopes()->count());
        $this->assertSame(1, Payment::query()->withoutGlobalScopes()->count());
        $this->assertSame(CardState::Active, $card->refresh()->state);
        $this->artisan('giftcard:verify-chains')->assertSuccessful();
    }

    /**
     * Forks WORKERS processes that wait at a barrier and then run `$work` at the same moment. Each returns
     * `ok:<result>` or `err:<error code>`.
     *
     * @param  \Closure(int): string  $work
     * @return list<string>
     */
    private function race(\Closure $work): array
    {
        DB::disconnect();
        $go = $this->dir.'/go';
        $pids = [];
        for ($i = 0; $i < self::WORKERS; $i++) {
            $pid = pcntl_fork();
            if ($pid === 0) {
                $out = $this->dir."/r{$i}";
                try {
                    DB::reconnect();
                    DB::select('select 1');
                    while (! file_exists($go)) {
                        usleep(1000);
                    }
                    $result = 'ok:'.$work($i);
                } catch (DomainException $e) {
                    $result = 'err:'.$e->errorCode();
                } catch (Throwable $e) {
                    $result = 'crash:'.$e::class.': '.$e->getMessage();
                }
                file_put_contents($out, $result);
                // Leave without PHPUnit's shutdown handlers or destructors.
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
        for ($i = 0; $i < self::WORKERS; $i++) {
            $results[] = (string) @file_get_contents($this->dir."/r{$i}");
        }
        foreach ($results as $r) {
            $this->assertStringStartsNotWith('crash:', $r);
            $this->assertNotSame('', $r, 'a worker did not report');
        }

        return $results;
    }

    private function actor(): Actor
    {
        return new Actor($this->manager->fresh());
    }

    /**
     * @template T
     *
     * @param  callable(): T  $callback
     * @return T
     */
    private function tenant(callable $callback): mixed
    {
        return app(TenantContext::class)->runAs($this->restaurant, $callback);
    }

    private function sellVoucher(int $value): Voucher
    {
        $sale = $this->tenant(fn () => app(VoucherService::class)->sell($this->actor(), new IssueVoucherData(
            value: $value,
            payment: new PaymentData(PaymentMethod::Cash),
            idempotencyKey: (string) Str::uuid(),
        )));
        $this->payloads[$sale->voucher->getKey()] = (string) $sale->printable?->payload;

        return $sale->voucher;
    }

    /** @var array<string, string> */
    private array $payloads = [];

    private function presentment(Voucher $voucher): string
    {
        return $this->tenant(fn (): string => app(PresentmentService::class)
            ->present($this->actor(), PresentmentPurpose::Spend, PresentmentMethod::PrintableQr, $this->payloads[$voucher->getKey()])
            ->getKey());
    }

    private function assertIntact(Voucher $voucher): void
    {
        $sum = (int) VoucherTransaction::query()->withoutGlobalScopes()->where('voucher_id', $voucher->getKey())->sum('amount');
        $this->assertSame(Voucher::query()->withoutGlobalScopes()->findOrFail($voucher->getKey())->balance, $sum);
        $this->artisan('giftcard:verify-chains')->assertSuccessful();
    }
}
