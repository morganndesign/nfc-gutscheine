<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Enums\UserStatus;
use App\Models\Device;
use App\Models\PersonalAccessToken;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/** Sign-in and device binding of the native waiter app (GiftCard Waiter). */
final class WaiterAppTokenTest extends TestCase
{
    private const DEVICE = 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff';

    /** @param array<string, mixed> $overrides */
    private function signIn(string $email, array $overrides = []): TestResponse
    {
        return $this->withHeaders(['User-Agent' => 'GiftCardWaiter/1.0.0 (Android 14; Pixel 7)'])
            ->postJson('/api/v1/auth/token', array_merge([
                'email' => $email,
                'password' => 'Password123!',
                'device_id' => self::DEVICE,
                'device_name' => 'Pixel 7',
                'platform' => 'android',
            ], $overrides));
    }

    private function bearer(string $token, string $device = self::DEVICE): self
    {
        $this->app['auth']->forgetGuards();

        return $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => $device]);
    }

    /** @return array{Restaurant, User, string} */
    private function signedInWaiter(): array
    {
        $restaurant = $this->restaurant(['name' => 'Trattoria Test']);
        $user = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);
        $token = (string) $this->signIn('anna@example.com')->assertCreated()->json('data.token');

        return [$restaurant, $user, $token];
    }

    public function test_waiter_signs_in_and_gets_a_device_bound_token(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);

        $response = $this->signIn('Anna@Example.com')
            ->assertCreated()
            ->assertJsonPath('data.user.id', $user->id)
            ->assertJsonPath('data.user.permissions', ['vouchers.redeem'])
            ->assertJsonPath('data.user.restaurant.id', $restaurant->id);

        $this->assertNotEmpty($response->json('data.token'));
        $expires = Carbon::parse((string) $response->json('data.expires_at'));
        $this->assertTrue($expires->between(Carbon::now()->addDays(29), Carbon::now()->addDays(31)));

        $device = Device::query()->withoutGlobalScopes()->sole();
        $this->assertSame('Pixel 7', $device->name);
        $this->assertSame('phone', $device->type);

        $token = PersonalAccessToken::query()->sole();
        $this->assertSame($device->id, $token->device_id);
        $this->assertSame($restaurant->id, $token->restaurant_id);
        $this->assertSame(['vouchers.redeem'], $token->abilities);
        $this->assertDatabaseHas('audit_logs', ['action' => 'auth.device_token_issued', 'user_id' => $user->id, 'device_id' => $device->id]);
    }

    public function test_token_can_present_and_redeem_with_idempotency(): void
    {
        [$restaurant, , $token] = $this->signedInWaiter();
        $sale = $this->sell($restaurant, 5000);
        $voucher = $sale->voucher;

        $this->bearer($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.permissions', ['vouchers.redeem'])
            ->assertJsonPath('data.restaurant.settings.max_debit_per_transaction', 25000);

        $presentment = $this->bearer($token)->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'printable_qr', 'credential' => $sale->printable->payload])
            ->assertCreated()->assertJsonPath('data.voucher.id', $voucher->id)->json('data.id');

        $key = (string) Str::uuid();
        $body = ['amount' => 1250, 'presentment_id' => $presentment];
        $this->bearer($token)->withHeaders(['Idempotency-Key' => $key])
            ->postJson("/api/v1/vouchers/{$voucher->id}/redemptions", $body)
            ->assertCreated()->assertJsonPath('data.voucher.balance', 3750);

        $this->bearer($token)->withHeaders(['Idempotency-Key' => $key])
            ->postJson("/api/v1/vouchers/{$voucher->id}/redemptions", $body)
            ->assertOk()->assertJsonPath('replayed', true)->assertJsonPath('data.voucher.balance', 3750);

        // After a lost answer the app asks for the key's outcome instead of sending the debit again.
        $this->bearer($token)->getJson("/api/v1/vouchers/{$voucher->id}/redemptions/{$key}")
            ->assertOk()->assertJsonPath('data.status', 'booked')->assertJsonPath('data.voucher.balance', 3750);

        $this->assertSame(3750, $voucher->refresh()->balance);
        $this->assertLedgerConsistent($voucher);
    }

    public function test_token_is_limited_to_the_waiter_endpoints_even_for_owners(): void
    {
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Owner, ['email' => 'owner@example.com']);
        $token = (string) $this->signIn('owner@example.com')->assertCreated()->json('data.token');
        $voucher = $this->issueVoucher($restaurant);

        $this->bearer($token)->getJson('/api/v1/vouchers')->assertForbidden();
        $this->bearer($token)->getJson("/api/v1/vouchers/{$voucher->id}")->assertForbidden();
        $this->bearer($token)->getJson('/api/v1/dashboard/stats')->assertForbidden();
        $this->bearer($token)->putJson('/api/v1/auth/profile', ['name' => 'Mallory'])->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');
        $this->bearer($token)->getJson('/api/v1/devices/current')->assertOk();
        // Method and path both count: the app never edits a voucher or reads its history.
        $this->bearer($token)->patchJson("/api/v1/vouchers/{$voucher->id}", ['notes' => 'x'])->assertForbidden();
        $this->bearer($token)->getJson("/api/v1/vouchers/{$voucher->id}/history")->assertForbidden();
    }

    public function test_token_is_rejected_from_another_device(): void
    {
        [, , $token] = $this->signedInWaiter();

        $this->bearer($token, 'ffffffff-0000-4000-8000-000000000000')->getJson('/api/v1/auth/me')
            ->assertUnauthorized()->assertJsonPath('code', 'UNAUTHENTICATED');

        $this->app['auth']->forgetGuards();
        $this->withHeaders(['Authorization' => 'Bearer '.$token])->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_revoking_the_device_stops_the_token_and_restoring_allows_it_again(): void
    {
        [$restaurant, , $token] = $this->signedInWaiter();
        $device = Device::query()->withoutGlobalScopes()->sole();

        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/devices/{$device->id}/revoke")->assertOk();

        $this->bearer($token)->getJson('/api/v1/auth/me')->assertForbidden()->assertJsonPath('code', 'DEVICE_REVOKED');
        $this->signIn('anna@example.com')->assertForbidden()->assertJsonPath('code', 'DEVICE_REVOKED');

        $this->flushHeaders();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/devices/{$device->id}/restore")->assertOk();
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertOk();
    }

    public function test_signing_in_again_replaces_the_previous_token(): void
    {
        [, , $first] = $this->signedInWaiter();
        $second = (string) $this->signIn('anna@example.com')->assertCreated()->json('data.token');

        $this->bearer($first)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->bearer($second)->getJson('/api/v1/auth/me')->assertOk();
        $this->assertSame(1, PersonalAccessToken::query()->whereNull('revoked_at')->count());
    }

    public function test_logout_revokes_the_token(): void
    {
        [, , $token] = $this->signedInWaiter();

        $this->bearer($token)->postJson('/api/v1/auth/logout')->assertOk();
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_expiry_rolls_forward_while_the_phone_is_used_and_expired_tokens_fail(): void
    {
        [, , $token] = $this->signedInWaiter();
        $model = PersonalAccessToken::query()->sole();

        $model->forceFill(['expires_at' => Carbon::now()->addDays(3)])->save();
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertOk();
        $this->assertTrue($model->refresh()->expires_at?->greaterThan(Carbon::now()->addDays(29)));

        $model->forceFill(['expires_at' => Carbon::now()->subMinute()])->save();
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_sign_in_rules_match_the_web_login(): void
    {
        config(['giftcard.security.login_lockout_threshold' => 2]);
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);

        $this->signIn('anna@example.com', ['password' => 'wrong'])->assertStatus(422)->assertJsonPath('code', 'VALIDATION_FAILED');
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.2'])->signIn('anna@example.com', ['password' => 'wrong']);
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.3'])->signIn('anna@example.com')
            ->assertStatus(422)
            ->assertJsonPath('code', 'VALIDATION_FAILED');
        $this->assertSame(0, PersonalAccessToken::query()->count());

        $this->signIn('anna@example.com', ['device_id' => 'short', 'platform' => 'windows'])
            ->assertStatus(422)->assertJsonValidationErrors(['device_id', 'platform']);
        $this->assertSame(0, PersonalAccessToken::query()->count());
    }

    public function test_platform_admins_and_suspended_restaurants_get_no_token(): void
    {
        User::factory()->platformAdmin()->create(['email' => 'admin@example.com']);
        $this->signIn('admin@example.com')->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');

        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);
        $restaurant->forceFill(['status' => 'suspended'])->save();
        $this->signIn('anna@example.com')->assertForbidden()->assertJsonPath('code', 'RESTAURANT_SUSPENDED');
    }

    public function test_deactivated_accounts_get_a_dedicated_code(): void
    {
        [, $user, $token] = $this->signedInWaiter();
        $user->forceFill(['status' => UserStatus::Inactive])->save();

        $this->bearer($token)->getJson('/api/v1/auth/me')->assertUnauthorized()->assertJsonPath('code', 'ACCOUNT_DEACTIVATED');
        $this->bearer($token)->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'printable_qr', 'credential' => 'x'])
            ->assertUnauthorized()->assertJsonPath('code', 'ACCOUNT_DEACTIVATED');
        $this->signIn('anna@example.com')->assertUnauthorized()->assertJsonPath('code', 'ACCOUNT_DEACTIVATED');
    }

    public function test_device_tokens_are_not_listed_as_integration_tokens(): void
    {
        [$restaurant] = $this->signedInWaiter();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->getJson('/api/v1/api-tokens')->assertOk()->assertJsonCount(0, 'data');
    }
}
