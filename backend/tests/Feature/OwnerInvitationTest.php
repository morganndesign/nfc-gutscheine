<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Jobs\SendStaffInvitation;
use App\Models\NotificationLog;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Queue\MaxAttemptsExceededException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Symfony\Component\Mailer\SentMessage;
use Tests\TestCase;

/**
 * Onboarding invitation: create restaurant → owner account → e-mail with a single-use link → owner
 * chooses a password → account active; every attempt logged; invitations can be sent again.
 */
final class OwnerInvitationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        // Real notification + mail rendering; the array transport keeps the messages in memory.
        config(['mail.default' => 'array', 'giftcard.frontend_url' => 'https://app.example.test']);
    }

    private function actingAsAdmin(): User
    {
        $admin = User::factory()->platformAdmin()->create(['name' => 'Platform Admin']);
        Sanctum::actingAs($admin, ['*']);

        return $admin;
    }

    /** @return list<SentMessage> */
    private function sentMails(): array
    {
        return array_values(iterator_to_array(app('mailer')->getSymfonyTransport()->messages()));
    }

    private function linkFrom(SentMessage $mail): string
    {
        $body = (string) $mail->getOriginalMessage()->getTextBody();
        preg_match('~https://app\.example\.test/reset-password#[^\s\]\)]+~', $body, $m);
        $this->assertNotEmpty($m, 'The invitation e-mail contains the password link.');

        return html_entity_decode($m[0]);
    }

    /** @return array{token: string, email: string, invite: string} */
    private function query(string $link): array
    {
        parse_str((string) parse_url($link, PHP_URL_FRAGMENT), $q);

        /** @var array{token: string, email: string, invite: string} $q */
        return $q;
    }

    private function onboard(): Restaurant
    {
        $id = $this->postJson('/api/v1/admin/restaurants', [
            'name' => 'Zum Goldenen Hirschen',
            'owner' => ['name' => 'Hanna Hirsch', 'email' => 'Hanna@Hirsch.test'],
        ])->assertCreated()
            ->assertJsonPath('owner.email', 'hanna@hirsch.test')
            ->assertJsonPath('owner.role.slug', 'owner')
            ->assertJsonPath('data.owner.invitation.status', 'pending')
            ->assertJsonPath('data.owner.invitation.delivery', 'sent')
            ->json('data.id');

        return Restaurant::query()->findOrFail($id);
    }

    public function test_complete_invitation_flow(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->onboard();

        // 1. One e-mail to the owner, with a single-use link.
        $mails = $this->sentMails();
        $this->assertCount(1, $mails);
        $this->assertSame('hanna@hirsch.test', $mails[0]->getOriginalMessage()->getTo()[0]->getAddress());
        $this->assertSame('Einladung zu GiftCard Pro', $mails[0]->getOriginalMessage()->getSubject());
        $body = (string) $mails[0]->getOriginalMessage()->getTextBody();
        $this->assertStringContainsString('Sie wurden als Inhaber des Restaurants „Zum Goldenen Hirschen“ zu GiftCard Pro eingeladen.', $body);
        $this->assertStringContainsString('support@giftcardpro.at', $body, 'Owners are told to contact support, not "their restaurant owner".');
        $q = $this->query($this->linkFrom($mails[0]));
        $this->assertSame('1', $q['invite']);
        $this->assertSame('hanna@hirsch.test', $q['email']);
        $this->assertGreaterThanOrEqual(40, strlen($q['token']));

        // 2. The token is stored only as a hash.
        $stored = (string) DB::table('password_reset_tokens')->where('email', 'hanna@hirsch.test')->value('token');
        $this->assertNotSame($q['token'], $stored);

        // 3. Logged in notification_logs.
        $log = NotificationLog::query()->where('recipient', 'hanna@hirsch.test')->sole();
        $this->assertSame('staff_invitation', $log->template_key);
        $this->assertSame('sent', $log->status);
        $this->assertSame($restaurant->id, $log->restaurant_id);
        $this->assertNotNull($log->sent_at);

        // 4. The owner cannot sign in before accepting.
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/login', ['email' => 'hanna@hirsch.test', 'password' => 'Hirsch-2026-Secure'])->assertUnprocessable();

        // 5. Accepting: choose a password with the link (activates the account).
        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $q['token'], 'email' => 'hanna@hirsch.test',
            'password' => 'Hirsch-2026-Secure', 'password_confirmation' => 'Hirsch-2026-Secure',
        ])->assertOk();
        $this->assertDatabaseHas('audit_logs', ['action' => 'user.invitation_accepted', 'restaurant_id' => $restaurant->id]);

        // 6. The link works once.
        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $q['token'], 'email' => 'hanna@hirsch.test',
            'password' => 'Another-2026-Secure', 'password_confirmation' => 'Another-2026-Secure',
        ])->assertUnprocessable();

        // 7. The owner signs in and works in the restaurant.
        $this->postJson('/api/v1/auth/login', ['email' => 'hanna@hirsch.test', 'password' => 'Hirsch-2026-Secure'])->assertOk();
        $owner = User::query()->where('email', 'hanna@hirsch.test')->firstOrFail();
        $this->assertNotNull($owner->password_changed_at);
        Sanctum::actingAs($owner, ['*']);
        $this->getJson('/api/v1/vouchers')->assertOk();

        // 8. The admin list shows the invitation as accepted.
        $this->actingAsAdmin();
        $this->getJson('/api/v1/admin/restaurants')->assertJsonPath('data.0.owner.invitation.status', 'accepted');
    }

    public function test_the_platform_invites_a_new_owner_when_the_restaurant_changes_hands(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->onboard();
        $old = User::query()->where('email', 'hanna@hirsch.test')->sole();

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/owners", ['name' => 'Paul Neu', 'email' => 'hanna@hirsch.test'])->assertStatus(422);
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/owners", ['name' => 'Paul Neu', 'email' => 'Paul@Neu.test'])->assertCreated()
            ->assertJsonPath('data.role.slug', 'owner')
            ->assertJsonPath('data.invitation.status', 'pending');
        $this->assertCount(2, $this->sentMails());
        $new = User::query()->where('email', 'paul@neu.test')->sole();

        // The new owner takes over and deactivates the previous one; the restaurant's owner is now the active one.
        Sanctum::actingAs($new, ['*']);
        $this->postJson("/api/v1/users/{$old->id}/deactivate")->assertOk();
        $this->assertSame($new->id, $restaurant->refresh()->owner()->first()?->id);

        // Owners never invite other restaurants' owners through this path.
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/owners", ['name' => 'X', 'email' => 'x@example.test'])->assertForbidden();
    }

    public function test_invitation_link_expires_after_72_hours(): void
    {
        $this->actingAsAdmin();
        $this->onboard();
        $q = $this->query($this->linkFrom($this->sentMails()[0]));

        $this->travel(73)->hours();
        $this->actingAsAdmin();
        $this->getJson('/api/v1/admin/restaurants')->assertJsonPath('data.0.owner.invitation.status', 'expired');

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $q['token'], 'email' => 'hanna@hirsch.test',
            'password' => 'Hirsch-2026-Secure', 'password_confirmation' => 'Hirsch-2026-Secure',
        ])->assertUnprocessable();
    }

    public function test_resend_replaces_the_link_and_is_logged(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->onboard();
        $first = $this->query($this->linkFrom($this->sentMails()[0]))['token'];

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation")
            ->assertOk()
            ->assertJsonPath('message', 'Invitation sent to hanna@hirsch.test.')
            ->assertJsonPath('data.invitation.status', 'pending')
            ->assertJsonPath('data.invitation.delivery', 'sent');

        $mails = $this->sentMails();
        $this->assertCount(2, $mails);
        $second = $this->query($this->linkFrom($mails[1]))['token'];
        $this->assertNotSame($first, $second);
        $this->assertSame(2, NotificationLog::query()->where('recipient', 'hanna@hirsch.test')->where('status', 'sent')->count());
        $this->assertDatabaseHas('audit_logs', ['action' => 'user.invitation_resent', 'restaurant_id' => $restaurant->id]);

        // Only the newest link works.
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $first, 'email' => 'hanna@hirsch.test', 'password' => 'Hirsch-2026-Secure', 'password_confirmation' => 'Hirsch-2026-Secure',
        ])->assertUnprocessable();
        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $second, 'email' => 'hanna@hirsch.test', 'password' => 'Hirsch-2026-Secure', 'password_confirmation' => 'Hirsch-2026-Secure',
        ])->assertOk();
    }

    public function test_resend_can_correct_a_mistyped_address(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->onboard();
        $old = $this->query($this->linkFrom($this->sentMails()[0]))['token'];

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation", ['email' => 'hanna@hirschen.test', 'name' => 'Hanna Hirschen'])
            ->assertOk()
            ->assertJsonPath('data.email', 'hanna@hirschen.test')
            ->assertJsonPath('data.name', 'Hanna Hirschen');

        $this->assertSame('hanna@hirschen.test', $this->sentMails()[1]->getOriginalMessage()->getTo()[0]->getAddress());
        $this->assertDatabaseMissing('password_reset_tokens', ['email' => 'hanna@hirsch.test']);
        $this->assertDatabaseHas('audit_logs', ['action' => 'user.updated', 'restaurant_id' => $restaurant->id]);

        // The old link is dead, the corrected address can accept.
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $old, 'email' => 'hanna@hirsch.test', 'password' => 'Hirsch-2026-Secure', 'password_confirmation' => 'Hirsch-2026-Secure',
        ])->assertUnprocessable();

        // An address that already has an account is refused.
        $this->actingAsAdmin();
        $other = $this->staff($this->restaurant(), RoleSlug::Manager);
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation", ['email' => $other->email])
            ->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_resend_is_refused_when_not_possible(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->onboard();
        $owner = User::query()->where('email', 'hanna@hirsch.test')->firstOrFail();

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/suspend", ['reason' => 'Test'])->assertOk();
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation")
            ->assertStatus(409)->assertJsonPath('code', 'INVITATION_NOT_POSSIBLE');
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/reactivate")->assertOk();

        $owner->forceFill(['password_changed_at' => now(), 'last_login_at' => now()])->save();
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation")
            ->assertStatus(409)->assertJsonPath('code', 'INVITATION_NOT_POSSIBLE');

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/archive")->assertOk();
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation")->assertNotFound();
    }

    public function test_resend_to_other_pending_staff_of_the_restaurant(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->onboard();
        $waiter = $this->staff($restaurant, RoleSlug::Waiter, ['password_changed_at' => null, 'last_login_at' => null]);
        $foreign = $this->staff($this->restaurant(), RoleSlug::Waiter, ['password_changed_at' => null, 'last_login_at' => null]);

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/users/{$waiter->id}/invitation")->assertOk();
        $this->assertStringContainsString(
            'bitten Sie die Restaurantleitung',
            (string) $this->sentMails()[1]->getOriginalMessage()->getTextBody(),
        );
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/users/{$foreign->id}/invitation")
            ->assertStatus(409)->assertJsonPath('code', 'INVITATION_NOT_POSSIBLE');

        $this->getJson("/api/v1/admin/restaurants/{$restaurant->id}")
            ->assertOk()
            ->assertJsonPath('data.owner.invitation.status', 'pending')
            ->assertJsonFragment(['email' => $waiter->email]);
    }

    public function test_mail_server_failure_is_logged_and_reported_without_losing_the_restaurant(): void
    {
        $this->actingAsAdmin();
        Notification::shouldReceive('send')->andThrow(new RuntimeException('Connection could not be established with host "smtp.example.test:587"'));

        $this->postJson('/api/v1/admin/restaurants', [
            'name' => 'Offline Bistro',
            'owner' => ['name' => 'Otto', 'email' => 'otto@bistro.test'],
        ])->assertCreated()
            ->assertJsonPath('data.owner.invitation.delivery', 'failed')
            ->assertJsonPath('data.owner.invitation.error', 'Connection could not be established with host "smtp.example.test:587"');

        $restaurant = Restaurant::query()->where('name', 'Offline Bistro')->sole();
        $this->assertSame('failed', NotificationLog::query()->where('recipient', 'otto@bistro.test')->sole()->status);

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation")
            ->assertUnprocessable()
            ->assertJsonPath('code', 'INVITATION_NOT_DELIVERED')
            ->assertJsonPath('data.invitation.delivery', 'failed');
    }

    public function test_an_invitation_job_lost_with_its_worker_is_reported_failed_not_queued_forever(): void
    {
        $owner = User::factory()->create(['email' => 'crash@bistro.test']);
        $log = NotificationLog::query()->create(['template_key' => 'staff_invitation', 'channel' => 'mail', 'recipient' => $owner->email, 'status' => 'queued']);
        $job = new SendStaffInvitation($owner->id, (string) $owner->restaurant_id, null, $log->id);

        // The worker was killed during the job: the queue gives up with MaxAttemptsExceeded and calls failed().
        $job->failed(new MaxAttemptsExceededException('App\Jobs\SendStaffInvitation has been attempted too many times.'));

        $log->refresh();
        $this->assertSame('failed', $log->status);
        $this->assertStringContainsString('attempted too many times', (string) $log->error);
    }

    public function test_log_mailer_is_reported_as_not_delivered(): void
    {
        config(['mail.default' => 'log']);
        $this->actingAsAdmin();

        $this->getJson('/api/v1/admin/mail')
            ->assertOk()
            ->assertJsonPath('data.mailer', 'log')
            ->assertJsonPath('data.delivers', false)
            ->assertJsonPath('data.problem', fn (string $p) => str_contains($p, 'MAIL_MAILER=smtp'));

        $id = $this->postJson('/api/v1/admin/restaurants', ['name' => 'Log Bistro', 'owner' => ['name' => 'L', 'email' => 'l@log.test']])
            ->assertCreated()
            ->assertJsonPath('data.owner.invitation.delivery', 'logged')
            ->json('data.id');

        $this->postJson("/api/v1/admin/restaurants/{$id}/invitation")
            ->assertUnprocessable()->assertJsonPath('code', 'INVITATION_NOT_DELIVERED');
        $this->postJson('/api/v1/admin/mail/test')->assertUnprocessable()->assertJsonPath('code', 'MAIL_NOT_DELIVERED');
    }

    public function test_admin_sends_a_test_mail_to_himself(): void
    {
        $admin = $this->actingAsAdmin();

        $this->getJson('/api/v1/admin/mail')->assertOk()->assertJsonPath('data.delivers', true);
        $this->postJson('/api/v1/admin/mail/test')->assertOk()->assertJsonPath('message', "Test e-mail sent to {$admin->email}.");
        $this->assertSame($admin->email, $this->sentMails()[0]->getOriginalMessage()->getTo()[0]->getAddress());
        $this->assertDatabaseHas('audit_logs', ['action' => 'platform.mail_test']);
    }

    public function test_staff_invitation_still_uses_the_same_flow(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->postJson('/api/v1/users', ['name' => 'Walter Waiter', 'email' => 'walter@example.test', 'role' => 'waiter'])->assertCreated();

        $this->assertCount(1, $this->sentMails());
        $this->assertSame('sent', NotificationLog::query()->where('recipient', 'walter@example.test')->sole()->status);
    }
}
