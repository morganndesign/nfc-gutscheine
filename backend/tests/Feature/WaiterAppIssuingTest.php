<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\PersonalAccessToken;
use App\Models\Restaurant;
use App\Models\Role;
use App\Models\Voucher;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Selling a voucher from GiftCard Waiter: managers and owners only, through the same endpoint and service as the
 * dashboard (POST /vouchers).
 */
final class WaiterAppIssuingTest extends TestCase
{
    private const DEVICE = 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff';

    private function signIn(string $email): TestResponse
    {
        return $this->withHeaders(['User-Agent' => 'GiftCardWaiter/1.4.3 (Android 14; Pixel 7)'])
            ->postJson('/api/v1/auth/token', [
                'email' => $email,
                'password' => 'Password123!',
                'device_id' => self::DEVICE,
                'device_name' => 'Pixel 7',
                'platform' => 'android',
            ]);
    }

    private function bearer(string $token): self
    {
        $this->app['auth']->forgetGuards();

        return $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => self::DEVICE]);
    }

    private function tokenFor(RoleSlug $role, string $email): string
    {
        $restaurant = $this->restaurant(['name' => 'Trattoria Test']);
        $this->staff($restaurant, $role, ['email' => $email]);

        return (string) $this->signIn($email)->assertCreated()->json('data.token');
    }

    /** @return array<string, mixed> */
    private function sale(): array
    {
        return ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'cash'], 'customer' => ['email' => 'guest@example.com']];
    }

    public function test_managers_and_owners_get_the_selling_ability_waiters_do_not(): void
    {
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Manager, ['email' => 'mia@example.com']);
        $this->staff($restaurant, RoleSlug::Owner, ['email' => 'otto@example.com']);
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);

        $expected = [
            'mia@example.com' => ['manager', ['vouchers.redeem', 'vouchers.sell', 'cards.receive', 'cards.bind', 'cards.view', 'cards.manage']],
            'otto@example.com' => ['owner', ['vouchers.redeem', 'vouchers.sell', 'vouchers.sell_complimentary', 'cards.receive', 'cards.bind', 'cards.view', 'cards.manage']],
        ];
        foreach ($expected as $email => [$role, $abilities]) {
            $permissions = $this->signIn($email)->assertCreated()
                ->assertJsonPath('data.user.role.slug', $role)
                ->json('data.user.permissions');
            $this->assertEqualsCanonicalizing($abilities, $permissions, $role);
        }

        $this->signIn('anna@example.com')->assertCreated()
            ->assertJsonPath('data.user.role.slug', 'waiter')
            ->assertJsonPath('data.user.permissions', ['vouchers.redeem']);
    }

    public function test_manager_sells_a_printable_voucher_in_the_app(): void
    {
        $token = $this->tokenFor(RoleSlug::Manager, 'mia@example.com');
        $key = (string) Str::uuid();

        $created = $this->bearer($token)->withHeaders(['Idempotency-Key' => $key])
            ->postJson('/api/v1/vouchers', $this->sale())
            ->assertCreated()
            ->assertJsonPath('data.balance', 5000)
            ->assertJsonMissingPath('data.voucher_number')
            ->assertJsonPath('data.expires_at', null)
            ->assertJsonPath('payment.method', 'cash')
            ->assertJsonPath('replayed', false);
        $voucherId = (string) $created->json('data.id');
        $qr = (string) $created->json('printable.payload');
        $this->assertStringStartsWith('GCPV1.', $qr);

        // A retry with the same key (answer lost) replays instead of selling a second voucher.
        $this->bearer($token)->withHeaders(['Idempotency-Key' => $key])
            ->postJson('/api/v1/vouchers', $this->sale())
            ->assertOk()->assertJsonPath('replayed', true)->assertJsonPath('data.id', $voucherId);
        $this->assertSame(1, Voucher::query()->count());
    }

    public function test_an_owner_records_a_complimentary_voucher_in_the_app(): void
    {
        $owner = $this->tokenFor(RoleSlug::Owner, 'otto@example.com');
        $this->bearer($owner)->withHeaders(['Idempotency-Key' => (string) Str::uuid()])
            ->postJson('/api/v1/vouchers', $this->complimentary())
            ->assertCreated()->assertJsonPath('payment.method', 'complimentary');
    }

    public function test_a_manager_cannot_record_a_complimentary_voucher(): void
    {
        $manager = $this->tokenFor(RoleSlug::Manager, 'mia@example.com');
        $this->bearer($manager)->withHeaders(['Idempotency-Key' => (string) Str::uuid()])
            ->postJson('/api/v1/vouchers', $this->complimentary())
            ->assertForbidden();
    }

    /** @return array<string, mixed> */
    private function complimentary(): array
    {
        return ['value' => 2000, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Regular guest birthday']];
    }

    public function test_the_app_token_reaches_nothing_else(): void
    {
        $token = $this->tokenFor(RoleSlug::Manager, 'mia@example.com');
        $voucher = $this->issueVoucher(Restaurant::query()->sole());

        $this->bearer($token)->getJson('/api/v1/vouchers')->assertForbidden();
        $this->bearer($token)->getJson("/api/v1/vouchers/{$voucher->id}")->assertForbidden();
        $this->bearer($token)->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$voucher->id}/reloads", ['amount' => 100, 'payment' => ['method' => 'cash']])->assertForbidden();
        $this->bearer($token)->postJson("/api/v1/vouchers/{$voucher->id}/expire", ['reason' => 'test'])->assertForbidden();
        $this->bearer($token)->getJson('/api/v1/customers')->assertForbidden();
    }

    public function test_waiters_cannot_sell_vouchers(): void
    {
        $token = $this->tokenFor(RoleSlug::Waiter, 'anna@example.com');

        $this->bearer($token)->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', $this->sale())
            ->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');
        $this->assertSame(0, Voucher::query()->count());
    }

    public function test_a_demoted_manager_loses_selling_immediately(): void
    {
        $restaurant = $this->restaurant();
        $manager = $this->staff($restaurant, RoleSlug::Manager, ['email' => 'mia@example.com']);
        $token = (string) $this->signIn('mia@example.com')->assertCreated()->json('data.token');

        $manager->forceFill(['role_id' => Role::query()->where('slug', RoleSlug::Waiter->value)->value('id')])->save();

        $this->bearer($token)->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', $this->sale())->assertForbidden();
        $this->assertSame(0, Voucher::query()->count());
    }

    public function test_the_daily_renewal_aligns_the_abilities_with_the_role(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);
        $token = (string) $this->signIn('anna@example.com')->assertCreated()->json('data.token');
        $model = PersonalAccessToken::query()->sole();
        $this->assertSame(['vouchers.redeem'], $model->abilities);

        // Promoted to manager; the next renewal (at most once a day) adds the selling ability.
        $user->forceFill(['role_id' => Role::query()->where('slug', RoleSlug::Manager->value)->value('id')])->save();
        $model->forceFill(['expires_at' => Carbon::now()->addDays(3)])->save();
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertOk();

        $this->assertSame(['vouchers.redeem', 'vouchers.sell', 'cards.receive', 'cards.bind', 'cards.view', 'cards.manage'], $model->refresh()->abilities);
        $this->assertEqualsCanonicalizing(
            ['vouchers.redeem', 'vouchers.sell', 'cards.receive', 'cards.bind', 'cards.view', 'cards.manage'],
            $this->bearer($token)->getJson('/api/v1/auth/me')->assertOk()->json('data.permissions'),
        );
    }
}
