<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Enums\RoleSlug;
use App\Enums\SecurityActorKind;
use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\ImmutableRecordException;
use App\Models\SecurityEvent;
use App\Models\SecurityEventSeal;
use App\Models\Voucher;
use App\Services\Integrity\ChainVerifier;
use App\Services\Security\SecurityEventRecorder;
use App\Services\Security\SecurityEventSealer;
use App\Support\Actor;
use App\Support\Database\AppendOnlyTriggers;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use LogicException;
use Tests\TestCase;

/** ADR-003: every security-sensitive action leaves one structured, immutable, sealed event. */
final class SecurityEventStreamTest extends TestCase
{
    private function event(SecurityEventType $type, ?SecurityEventOutcome $outcome = null): SecurityEvent
    {
        return SecurityEvent::query()
            ->where('type', $type->value)
            ->when($outcome !== null, static fn ($q) => $q->where('outcome', $outcome->value))
            ->orderByDesc('seq')
            ->firstOrFail();
    }

    public function test_sign_in_attempts_are_recorded_pseudonymously(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);

        $this->postJson('/api/v1/auth/login', ['email' => 'ghost@example.com', 'password' => 'nope'])->assertUnprocessable();
        $unknown = $this->event(SecurityEventType::SignIn, SecurityEventOutcome::Refused);
        $this->assertSame('invalid_credentials', $unknown->reason);
        $this->assertSame(SecurityActorKind::Anonymous, $unknown->actor_kind);
        $this->assertNull($unknown->subject_id);
        $this->assertSame(64, strlen((string) $unknown->data['email_hash']));
        $this->assertSame(64, strlen((string) $unknown->ip_hash));
        $this->assertSame('127.0.0.0/24', $unknown->ip_network);

        $this->postJson('/api/v1/auth/login', ['email' => 'anna@example.com', 'password' => 'wrong'])->assertUnprocessable();
        $wrong = $this->event(SecurityEventType::SignIn, SecurityEventOutcome::Refused);
        $this->assertSame($user->id, $wrong->subject_id);
        $this->assertSame($restaurant->id, $wrong->restaurant_id);
        $this->assertSame(1, $wrong->data['attempts']);
        $this->assertSame('web', $wrong->data['channel']);

        $this->postJson('/api/v1/auth/login', ['email' => 'anna@example.com', 'password' => 'Password123!'])->assertOk();
        $ok = $this->event(SecurityEventType::SignIn, SecurityEventOutcome::Succeeded);
        $this->assertSame($user->id, $ok->user_id);
        $this->assertSame(SecurityActorKind::User, $ok->actor_kind);

        // Nothing readable is stored: no address, no e-mail, no user agent.
        $raw = json_encode(SecurityEvent::query()->get()->toArray(), JSON_THROW_ON_ERROR);
        $this->assertStringNotContainsString('anna@example.com', $raw);
        $this->assertStringNotContainsString('ghost@example.com', $raw);
        $this->assertStringNotContainsString('127.0.0.1', $raw);
    }

    public function test_repeated_wrong_passwords_lock_the_account_and_the_lock_is_an_event(): void
    {
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);
        config(['giftcard.security.login_lockout_threshold' => 3]);
        $threshold = 3;

        for ($i = 0; $i < $threshold; $i++) {
            $this->postJson('/api/v1/auth/login', ['email' => 'anna@example.com', 'password' => 'wrong'.$i]);
        }
        $this->assertSame($threshold, $this->event(SecurityEventType::AccountLock)->data['attempts']);

        $this->postJson('/api/v1/auth/login', ['email' => 'anna@example.com', 'password' => 'Password123!'])->assertUnprocessable();
        $this->assertSame('account_locked', $this->event(SecurityEventType::SignIn, SecurityEventOutcome::Refused)->reason);
    }

    public function test_a_sign_in_flood_is_recorded_once_per_minute(): void
    {
        for ($i = 0; $i < 9; $i++) {
            $this->postJson('/api/v1/auth/login', ['email' => 'target@example.com', 'password' => 'x'.$i]);
        }

        $this->assertSame(1, SecurityEvent::query()->where('type', SecurityEventType::SignInThrottle->value)->count());
    }

    public function test_money_actions_record_amount_outcome_and_reason(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $sale = $this->postJson('/api/v1/vouchers', [
            'value' => 3000,
            'form' => 'printable',
            'payment' => $this->cashPayment(),
        ], $this->idempotency())->assertCreated();
        $voucherId = (string) $sale->json('data.id');
        $qr = (string) $sale->json('printable.payload');

        $issued = $this->event(SecurityEventType::VoucherIssue);
        $this->assertSame($voucherId, $issued->subject_id);
        $this->assertSame('voucher', $issued->subject_type);
        $this->assertSame(3000, $issued->amount);
        $this->assertSame('EUR', $issued->currency);
        $this->assertSame('cash', $issued->data['payment_method']);

        $voucher = Voucher::query()->findOrFail($voucherId);
        $this->redeemWithQr($voucher, $qr, 1000)->assertCreated();
        $redeemed = $this->event(SecurityEventType::VoucherRedeem, SecurityEventOutcome::Succeeded);
        $this->assertSame(1000, $redeemed->amount);
        $this->assertSame(2000, $redeemed->data['balance_after']);
        $this->assertSame(SecurityEventOutcome::Succeeded, $this->event(SecurityEventType::VoucherScan)->outcome);

        $this->redeemWithQr($voucher, $qr, 5000)->assertUnprocessable();
        $refused = $this->event(SecurityEventType::VoucherRedeem, SecurityEventOutcome::Refused);
        $this->assertSame('INSUFFICIENT_BALANCE', $refused->reason);
        $this->assertSame(5000, $refused->amount);

        $this->present('GCPV1.'.str_repeat('A', 43))->assertStatus(422);
        $this->assertSame('MEDIUM_NOT_RECOGNIZED', $this->event(SecurityEventType::VoucherScan, SecurityEventOutcome::Refused)->reason);

        $this->postJson("/api/v1/vouchers/{$voucherId}/block", ['reason' => 'Suspicious'])->assertOk();
        $this->assertSame('active', $this->event(SecurityEventType::VoucherBlock)->data['previous_status']);

        // Refusals survive the rolled-back transaction of the refused action.
        $this->redeemWithQr($voucher, $qr, 100)->assertUnprocessable();
        $this->assertStringStartsWith('VOUCHER_BLOCKED', (string) $this->event(SecurityEventType::VoucherRedeem, SecurityEventOutcome::Refused)->reason);
    }

    public function test_a_sale_outside_the_limits_is_a_refused_issue(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson('/api/v1/vouchers', ['value' => 1, 'form' => 'printable', 'payment' => $this->cashPayment()], $this->idempotency())
            ->assertUnprocessable();

        $refused = $this->event(SecurityEventType::VoucherIssue, SecurityEventOutcome::Refused);
        $this->assertSame('INVALID_AMOUNT', $refused->reason);
        $this->assertSame(1, $refused->amount);
        $this->assertNull($refused->subject_id);
    }

    public function test_an_app_token_used_for_something_else_is_refused_and_recorded(): void
    {
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);
        $token = (string) $this->postJson('/api/v1/auth/token', [
            'email' => 'anna@example.com',
            'password' => 'Password123!',
            'device_id' => 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff',
            'device_name' => 'Pixel 7',
            'platform' => 'android',
        ])->assertCreated()->json('data.token');
        $this->assertSame('android', $this->event(SecurityEventType::DeviceTokenIssue)->data['platform']);
        $this->assertSame('app', $this->event(SecurityEventType::SignIn)->data['channel']);
        $this->assertSame(SecurityEventType::DeviceRegister, SecurityEvent::query()->where('type', SecurityEventType::DeviceRegister->value)->sole()->type);

        $this->app['auth']->forgetGuards();
        $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff'])
            ->getJson('/api/v1/vouchers')->assertForbidden();
        $refused = $this->event(SecurityEventType::DeviceTokenUse, SecurityEventOutcome::Refused);
        $this->assertSame('ROUTE_NOT_ALLOWED', $refused->reason);
        $this->assertEquals(['method' => 'GET', 'route' => 'api/v1/vouchers'], $refused->data);

        $this->app['auth']->forgetGuards();
        $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => '00000000-0000-4000-8000-000000000000'])
            ->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->assertSame('OTHER_DEVICE', $this->event(SecurityEventType::DeviceTokenUse)->reason);
    }

    public function test_only_declared_data_keys_are_accepted(): void
    {
        $this->expectException(LogicException::class);

        app(SecurityEventRecorder::class)->record(SecurityEventType::SignOut, Actor::system(), data: ['password' => 'x']);
    }

    public function test_events_can_never_be_changed_or_deleted(): void
    {
        $event = app(SecurityEventRecorder::class)->record(SecurityEventType::SignOut, Actor::system(), data: ['channel' => 'web']);

        try {
            $event->forceFill(['reason' => 'x'])->save();
            $this->fail('An event was changed.');
        } catch (ImmutableRecordException) {
        }

        foreach (['UPDATE security_events SET reason = ?', 'DELETE FROM security_events WHERE 1 = ?'] as $sql) {
            try {
                DB::statement($sql, [1]);
                $this->fail('The database accepted: '.$sql);
            } catch (QueryException $e) {
                $this->assertStringContainsString('append-only', $e->getMessage());
            }
        }
    }

    public function test_settled_events_are_sealed_and_verified(): void
    {
        $recorder = app(SecurityEventRecorder::class);
        $sealer = app(SecurityEventSealer::class);

        Carbon::setTestNow(Carbon::parse('2026-10-01 10:00:00'));
        $recorder->record(SecurityEventType::SignOut, Actor::system(), data: ['channel' => 'web']);
        $recorder->record(SecurityEventType::VoucherScan, Actor::system(), SecurityEventOutcome::Refused, 'MEDIUM_NOT_RECOGNIZED', data: ['method' => 'printable_qr']);
        Carbon::setTestNow(Carbon::parse('2026-10-01 10:06:00'));
        $recent = $recorder->record(SecurityEventType::SignOut, Actor::system(), data: ['channel' => 'app']);

        // Only what has settled is sealed; the recent event waits for the next run.
        $this->assertSame(1, $sealer->seal());
        $seal = SecurityEventSeal::query()->sole();
        $this->assertSame(2, $seal->event_count);
        $this->assertSame($recent->seq - 1, $seal->to_seq);

        Carbon::setTestNow(Carbon::parse('2026-10-01 10:12:00'));
        $this->assertSame(1, $sealer->seal());
        $this->assertSame(0, $sealer->seal());
        $this->assertSame([], $sealer->verify());
        $this->assertSame([], app(ChainVerifier::class)->verify());
    }

    public function test_a_changed_sealed_event_is_detected(): void
    {
        $recorder = app(SecurityEventRecorder::class);
        Carbon::setTestNow(Carbon::parse('2026-10-01 10:00:00'));
        $recorder->record(SecurityEventType::SignOut, Actor::system(), data: ['channel' => 'web']);
        $event = $recorder->record(SecurityEventType::VoucherRedeem, Actor::system(), amount: 1000, currency: 'EUR');
        Carbon::setTestNow(Carbon::parse('2026-10-01 10:10:00'));
        app(SecurityEventSealer::class)->seal();
        $this->assertSame([], app(SecurityEventSealer::class)->verify());

        // Someone with database rights removes the protection and rewrites history.
        AppendOnlyTriggers::drop('security_events');
        DB::table('security_events')->where('seq', $event->seq)->update(['amount' => 10]);
        AppendOnlyTriggers::create('security_events');

        $problems = app(ChainVerifier::class)->verify();
        $this->assertNotEmpty(array_filter($problems, static fn (string $p): bool => str_contains($p, 'do not match their seal')));
    }

    public function test_events_that_should_be_sealed_but_are_not_are_reported(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-10-01 10:00:00'));
        app(SecurityEventRecorder::class)->record(SecurityEventType::SignOut, Actor::system(), data: ['channel' => 'web']);
        Carbon::setTestNow(Carbon::parse('2026-10-01 12:00:00'));

        $this->assertNotEmpty(array_filter(app(SecurityEventSealer::class)->verify(), static fn (string $p): bool => str_contains($p, 'not sealed')));
    }

    public function test_the_export_is_json_lines_of_sealed_events(): void
    {
        $recorder = app(SecurityEventRecorder::class);
        Carbon::setTestNow(Carbon::parse('2026-10-01 10:00:00'));
        $recorder->record(SecurityEventType::SignOut, Actor::system(), data: ['channel' => 'web']);
        $recorder->record(SecurityEventType::SignOut, Actor::system(), data: ['channel' => 'app']);
        Carbon::setTestNow(Carbon::parse('2026-10-01 10:10:00'));
        app(SecurityEventSealer::class)->seal();
        $recorder->record(SecurityEventType::SignOut, Actor::system(), data: ['channel' => 'web']);

        $path = tempnam(sys_get_temp_dir(), 'events');
        $this->artisan('giftcard:export-security-events', ['--output' => $path])->assertSuccessful();
        $lines = array_values(array_filter(explode("\n", (string) file_get_contents($path))));
        unlink($path);

        $this->assertCount(2, $lines, 'unsealed events are not exported');
        $row = json_decode($lines[0], true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('auth.sign_out', $row['type']);
        $this->assertSame('succeeded', $row['outcome']);
        $this->assertSame('system', $row['actor_kind']);
        $this->assertSame(['channel' => 'web'], $row['data']);
        $this->assertSame('2026-10-01T10:00:00.000000Z', $row['occurred_at']);
    }
}
