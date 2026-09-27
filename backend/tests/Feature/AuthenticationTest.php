<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

final class AuthenticationTest extends TestCase
{
    private function login(string $email, string $password = 'Password123!'): TestResponse
    {
        return $this->withHeader('Origin', 'http://localhost:3000')
            ->postJson('/api/v1/auth/login', ['email' => $email, 'password' => $password]);
    }

    public function test_staff_can_log_in_and_receives_profile_with_permissions(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);

        $this->login('ANNA@example.com')
            ->assertOk()
            ->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('data.role.slug', 'waiter')
            ->assertJsonPath('data.restaurant.id', $restaurant->id)
            ->assertJsonPath('data.permissions', ['cards.scan', 'cards.redeem']);

        $this->assertNotNull($user->refresh()->last_login_at);
        $this->assertDatabaseHas('audit_logs', ['action' => 'auth.login', 'user_id' => $user->id]);
    }

    public function test_invalid_credentials_are_rejected_generically(): void
    {
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);

        $this->login('anna@example.com', 'wrong-password')->assertStatus(422)->assertJsonPath('code', 'VALIDATION_FAILED');
        $this->login('nobody@example.com', 'wrong-password')->assertStatus(422);
    }

    public function test_account_is_locked_after_repeated_failures(): void
    {
        config(['giftcard.security.login_lockout_threshold' => 3]);
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Manager, ['email' => 'luca@example.com']);

        foreach (range(1, 3) as $i) {
            $this->withServerVariables(['REMOTE_ADDR' => "10.0.0.{$i}"])->login('luca@example.com', 'nope');
        }

        $this->assertTrue($user->refresh()->isLocked());
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.9'])->login('luca@example.com')->assertStatus(423)->assertJsonPath('code', 'ACCOUNT_LOCKED');
        $this->assertTrue(AuditLog::query()->where('action', 'auth.locked')->exists());
    }

    public function test_login_is_rate_limited(): void
    {
        $this->restaurant();

        foreach (range(1, 5) as $i) {
            $this->login('someone@example.com', 'nope')->assertStatus(422);
        }

        $this->login('someone@example.com', 'nope')->assertStatus(429)->assertJsonPath('code', 'TOO_MANY_REQUESTS');
    }

    public function test_deactivated_users_cannot_log_in(): void
    {
        $restaurant = $this->restaurant();
        User::factory()->forRestaurant($restaurant)->inactive()->create(['email' => 'gone@example.com']);

        $this->login('gone@example.com')->assertStatus(422);
    }

    public function test_users_of_suspended_restaurants_cannot_log_in(): void
    {
        $restaurant = $this->restaurant(['status' => 'suspended']);
        $this->staff($restaurant, RoleSlug::Owner, ['email' => 'owner@example.com']);

        $this->login('owner@example.com')->assertStatus(403)->assertJsonPath('code', 'RESTAURANT_SUSPENDED');
    }

    public function test_guests_receive_401_on_protected_routes(): void
    {
        $this->getJson('/api/v1/auth/me')->assertUnauthorized()->assertJsonPath('code', 'UNAUTHENTICATED');
        $this->getJson('/api/v1/cards')->assertUnauthorized();
    }

    public function test_user_can_change_password(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->putJson('/api/v1/auth/password', [
            'current_password' => 'Password123!',
            'password' => 'NewSecret12345',
            'password_confirmation' => 'NewSecret12345',
        ])->assertOk();

        $this->assertTrue(password_verify('NewSecret12345', $user->refresh()->password));
    }
}
