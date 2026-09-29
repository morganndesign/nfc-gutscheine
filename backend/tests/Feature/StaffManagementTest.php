<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\User;
use App\Notifications\StaffInvitation;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

final class StaffManagementTest extends TestCase
{
    public function test_owner_invites_a_waiter(): void
    {
        Notification::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->postJson('/api/v1/users', ['name' => 'Tom Waiter', 'email' => 'tom@example.com', 'role' => 'waiter'])
            ->assertCreated()
            ->assertJsonPath('data.role.slug', 'waiter')
            ->assertJsonPath('data.restaurant_id', $restaurant->id);

        Notification::assertSentTo(User::query()->where('email', 'tom@example.com')->firstOrFail(), StaffInvitation::class);
    }

    public function test_platform_role_cannot_be_assigned_by_owner(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->postJson('/api/v1/users', ['name' => 'Evil', 'email' => 'evil@example.com', 'role' => 'platform_admin'])
            ->assertJsonValidationErrors('role');
    }

    public function test_deactivation_revokes_access_and_protects_last_owner(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $waiter = $this->staff($restaurant, RoleSlug::Waiter);
        $token = $waiter->createToken('pos', ['vouchers.redeem']);
        $token->accessToken->forceFill(['restaurant_id' => $restaurant->id])->save();

        $this->postJson("/api/v1/users/{$waiter->id}/deactivate")->assertOk()->assertJsonPath('data.status', 'inactive');
        $this->assertNotNull($token->accessToken->refresh()->revoked_at);

        $this->postJson("/api/v1/users/{$owner->id}/deactivate")->assertForbidden()->assertJsonPath('code', 'ROLE_ASSIGNMENT_FORBIDDEN');

        $this->postJson("/api/v1/users/{$waiter->id}/activate")->assertOk()->assertJsonPath('data.status', 'active');
    }

    public function test_users_are_never_hard_deleted(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $waiter = $this->staff($restaurant, RoleSlug::Waiter);

        $this->deleteJson("/api/v1/users/{$waiter->id}")->assertStatus(405);
    }

    public function test_owner_cannot_change_own_role(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->patchJson("/api/v1/users/{$owner->id}", ['role' => 'waiter'])->assertForbidden();
    }

    public function test_invited_staff_can_set_a_password_for_72_hours(): void
    {
        Notification::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson('/api/v1/users', ['name' => 'New Waiter', 'email' => 'new@example.com', 'role' => 'waiter'])->assertCreated();

        $user = User::query()->where('email', 'new@example.com')->firstOrFail();
        $token = null;
        Notification::assertSentTo($user, StaffInvitation::class, function (StaffInvitation $n) use ($user, &$token): bool {
            $url = $n->toMail($user)->actionUrl;
            parse_str((string) parse_url($url, PHP_URL_QUERY), $query);
            $token = $query['token'] ?? null;

            return ($query['invite'] ?? null) === '1';
        });

        $this->travel(48)->hours();
        $this->app['auth']->forgetGuards();

        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $token, 'email' => 'new@example.com', 'password' => 'Welcome12345', 'password_confirmation' => 'Welcome12345',
        ])->assertOk();

        $this->assertTrue(password_verify('Welcome12345', $user->refresh()->password));
    }

    public function test_forgot_password_links_expire_after_an_hour(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Manager, ['email' => 'm@example.com']);
        $user->forceFill(['last_login_at' => now()])->save();
        $token = Password::broker()->createToken($user);

        $this->travel(2)->hours();

        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $token, 'email' => 'm@example.com', 'password' => 'Welcome12345', 'password_confirmation' => 'Welcome12345',
        ])->assertStatus(422);
    }
}
