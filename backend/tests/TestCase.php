<?php

declare(strict_types=1);

namespace Tests;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Data\SaleResult;
use App\Enums\PaymentMethod;
use App\Enums\RoleSlug;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Database\Seeders\NotificationTemplateSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Database\Seeders\SystemSettingsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;

abstract class TestCase extends BaseTestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed([RolesAndPermissionsSeeder::class, NotificationTemplateSeeder::class, SystemSettingsSeeder::class]);
    }

    protected function restaurant(array $attributes = []): Restaurant
    {
        return Restaurant::factory()->create($attributes)->load('settings');
    }

    protected function staff(Restaurant $restaurant, RoleSlug $role = RoleSlug::Manager, array $attributes = []): User
    {
        return User::factory()->forRestaurant($restaurant)->role($role)->create($attributes);
    }

    protected function actingAsStaff(Restaurant $restaurant, RoleSlug $role = RoleSlug::Manager): User
    {
        $user = $this->staff($restaurant, $role);
        Sanctum::actingAs($user, ['*']);

        return $user;
    }

    /**
     * Sells a digital voucher through the service layer (payment, ledger, printable QR), within the restaurant's
     * tenant context. The result carries the printable QR payload.
     */
    protected function sell(Restaurant $restaurant, int $value = 5000, ?User $by = null, ?string $customerId = null): SaleResult
    {
        return $this->asTenant($restaurant, function () use ($restaurant, $value, $by, $customerId): SaleResult {
            $by ??= $this->staff($restaurant, RoleSlug::Manager);

            return app(VoucherService::class)->sell(new Actor($by), new IssueVoucherData(
                value: $value,
                payment: new PaymentData(PaymentMethod::Cash),
                idempotencyKey: (string) Str::uuid(),
                customerId: $customerId,
            ));
        });
    }

    /** Sells a voucher and returns it (see {@see sell()}). */
    protected function issueVoucher(Restaurant $restaurant, int $value = 5000, ?User $by = null): Voucher
    {
        return $this->sell($restaurant, $value, $by)->voucher;
    }

    /** The till scans a printable QR: POST /presentments (spend). */
    protected function present(string $qr, array $headers = []): TestResponse
    {
        return $this->withHeaders($headers)->postJson('/api/v1/presentments', [
            'purpose' => 'spend',
            'method' => 'printable_qr',
            'credential' => $qr,
        ]);
    }

    /** Scans the voucher's QR and redeems `$amount` with the resulting presentment, as the current user. */
    protected function redeemWithQr(Voucher $voucher, string $qr, int $amount, ?string $key = null, array $headers = []): TestResponse
    {
        $presentment = $this->present($qr, $headers)->assertCreated()->json('data.id');

        return $this->withHeaders($headers + $this->idempotency($key))
            ->postJson("/api/v1/vouchers/{$voucher->id}/redemptions", ['amount' => $amount, 'presentment_id' => $presentment]);
    }

    /**
     * @template T
     *
     * @param  callable(): T  $callback
     * @return T
     */
    protected function asTenant(Restaurant $restaurant, callable $callback): mixed
    {
        return app(TenantContext::class)->runAs($restaurant->load('settings'), $callback);
    }

    /** @return array<string, string> */
    protected function idempotency(?string $key = null): array
    {
        return ['Idempotency-Key' => $key ?? (string) Str::uuid()];
    }

    /** @return array<string, mixed> */
    protected function cashPayment(): array
    {
        return ['method' => 'cash'];
    }

    protected function assertLedgerConsistent(Voucher $voucher): void
    {
        $sum = (int) VoucherTransaction::query()->withoutGlobalScopes()->where('voucher_id', $voucher->getKey())->sum('amount');

        $this->assertSame(
            Voucher::query()->withoutGlobalScopes()->findOrFail($voucher->getKey())->balance,
            $sum,
            'A voucher balance must equal the sum of its ledger entries.',
        );
    }
}
