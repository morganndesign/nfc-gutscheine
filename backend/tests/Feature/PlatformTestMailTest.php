<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Mockery;
use Symfony\Component\Mailer\Exception\TransportException;
use Symfony\Component\Mailer\SentMessage;
use Tests\TestCase;

/**
 * System settings → "Send test e-mail to me": sends to the signed-in platform administrator (or an explicit
 * address), logs the recipient first, and never tries to deliver to a missing or undeliverable address.
 */
final class PlatformTestMailTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['mail.default' => 'array']);
    }

    /** @return list<SentMessage> */
    private function sent(): array
    {
        return array_values(iterator_to_array(app('mailer')->getSymfonyTransport()->messages()));
    }

    public function test_sends_to_the_authenticated_platform_admin_and_logs_the_recipient(): void
    {
        Log::spy();
        $admin = User::factory()->platformAdmin()->create(['email' => 'ops@example.com']);
        Sanctum::actingAs($admin, ['*']);

        $this->postJson('/api/v1/admin/mail/test')
            ->assertOk()
            ->assertJsonPath('message', 'Test e-mail sent to ops@example.com.')
            ->assertJsonPath('data.recipient', 'ops@example.com')
            ->assertJsonPath('data.guard', 'sanctum (API token)');

        $sent = $this->sent();
        $this->assertCount(1, $sent);
        $this->assertSame('ops@example.com', $sent[0]->getOriginalMessage()->getTo()[0]->getAddress());
        Log::shouldHaveReceived('info')->with('Platform test e-mail requested', Mockery::on(
            // No e-mail address in the logs (personal data); the audit trail names the person.
            static fn (array $c): bool => ! array_key_exists('recipient', $c) && ! array_key_exists('user_email', $c)
                && $c['recipient_source'] === 'authenticated user'
                && $c['user_id'] === $admin->id,
        ))->once();
        $this->assertDatabaseHas('audit_logs', ['action' => 'platform.mail_test', 'user_id' => $admin->id]);
    }

    public function test_dashboard_session_uses_the_web_guard(): void
    {
        $admin = User::factory()->platformAdmin()->create(['email' => 'session-admin@example.com']);
        $this->actingAs($admin, 'web');

        $this->postJson('/api/v1/admin/mail/test')
            ->assertOk()
            ->assertJsonPath('data.recipient', 'session-admin@example.com')
            ->assertJsonPath('data.guard', 'web (session via Sanctum)');
    }

    public function test_an_explicit_recipient_can_be_given(): void
    {
        Sanctum::actingAs(User::factory()->platformAdmin()->create(['email' => 'ops@example.com']), ['*']);

        $this->postJson('/api/v1/admin/mail/test', ['to' => ' Owner@Gmail.example '])
            ->assertOk()->assertJsonPath('data.recipient', 'owner@gmail.example');
        $this->assertSame('owner@gmail.example', $this->sent()[0]->getOriginalMessage()->getTo()[0]->getAddress());
    }

    public function test_missing_recipient_is_a_validation_error_and_nothing_is_sent(): void
    {
        $admin = User::factory()->platformAdmin()->create();
        $admin->forceFill(['email' => ''])->saveQuietly();
        Sanctum::actingAs($admin->fresh(), ['*']);
        Mail::shouldReceive('raw')->never();

        $this->postJson('/api/v1/admin/mail/test')
            ->assertUnprocessable()
            ->assertJsonPath('code', 'VALIDATION_FAILED')
            ->assertJsonPath('errors.to.0', 'Your account has no e-mail address. Enter a recipient for the test e-mail.');
    }

    public function test_invalid_recipient_is_a_validation_error_and_nothing_is_sent(): void
    {
        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);
        Mail::shouldReceive('raw')->never();

        $this->postJson('/api/v1/admin/mail/test', ['to' => 'not-an-address'])
            ->assertUnprocessable()->assertJsonValidationErrors('to');
    }

    public function test_domain_without_mail_server_is_refused_before_sending(): void
    {
        config(['giftcard.verify_mail_domains' => true]);
        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);
        Mail::shouldReceive('raw')->never();

        // .invalid never resolves (RFC 2606), also without network access.
        $this->postJson('/api/v1/admin/mail/test', ['to' => 'admin@giftcardpro.invalid'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.to.0', '"admin@giftcardpro.invalid" cannot receive e-mail: the address is invalid or its domain has no mail server (MX record).');
    }

    public function test_recipient_rejected_by_the_mail_server_is_reported_with_the_address(): void
    {
        Sanctum::actingAs(User::factory()->platformAdmin()->create(['email' => 'admin@nomailbox.example']), ['*']);
        Mail::shouldReceive('raw')->once()->andThrow(new TransportException(
            'Expected response code "250/251/252" but got code "550", with message "550 Unrouteable address".',
        ));

        $this->postJson('/api/v1/admin/mail/test')
            ->assertUnprocessable()
            ->assertJsonPath('code', 'MAIL_RECIPIENT_REJECTED')
            ->assertJsonPath('data.recipient', 'admin@nomailbox.example')
            ->assertJsonPath('message', fn (string $m): bool => str_contains($m, 'refused the recipient admin@nomailbox.example')
                && str_contains($m, '550 Unrouteable address')
                && str_contains($m, 'Test with another address'));
    }

    public function test_other_transport_errors_are_reported_as_not_delivered(): void
    {
        Sanctum::actingAs(User::factory()->platformAdmin()->create(['email' => 'ops@example.com']), ['*']);
        Mail::shouldReceive('raw')->once()->andThrow(new TransportException('Connection could not be established with host "mail.example.com:587"'));

        $this->postJson('/api/v1/admin/mail/test')
            ->assertUnprocessable()
            ->assertJsonPath('code', 'MAIL_NOT_DELIVERED');
    }

    public function test_mail_status_reports_the_smtp_server_without_credentials(): void
    {
        config([
            'mail.default' => 'smtp',
            'mail.mailers.smtp.host' => 'mail.your-server.de',
            'mail.mailers.smtp.port' => 587,
            'mail.mailers.smtp.password' => 'secret-password',
        ]);
        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);

        $response = $this->getJson('/api/v1/admin/mail')
            ->assertOk()
            ->assertJsonPath('data.mailer', 'smtp')
            ->assertJsonPath('data.delivers', true)
            ->assertJsonPath('data.host', 'mail.your-server.de')
            ->assertJsonPath('data.port', 587)
            ->assertJsonPath('data.problem', null);
        $this->assertStringNotContainsString('secret-password', (string) $response->getContent());
    }
}
