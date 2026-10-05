<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Enums\PaymentMethod;
use App\Enums\RoleSlug;
use App\Mail\TemplatedMail;
use App\Models\PersonalAccessToken;
use App\Services\Auth\LoginCodeService;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Audit 2026-10-06, package 4 (and the server side of package 3). */
final class AuditPackageFourTest extends TestCase
{
    private const SPA = ['Origin' => 'http://localhost:3000'];

    /** S5: a lock never shuts out the person on their own trusted browser (but still everybody else). */
    public function test_a_locked_account_still_signs_in_on_its_trusted_browser(): void
    {
        $owner = $this->staff($this->restaurant(), RoleSlug::Owner, ['email' => 'otto@example.com']);
        $cookie = $this->webLogin('otto@example.com', 'Password123!')->assertOk()->getCookie(LoginCodeService::COOKIE)?->getValue();
        $this->assertIsString($cookie);
        $this->app['auth']->forgetGuards();
        $owner->forceFill(['locked_until' => Carbon::now()->addMinutes(15)])->save();

        $credentials = ['email' => 'otto@example.com', 'password' => 'Password123!'];
        $this->postJson('/api/v1/auth/login', $credentials, self::SPA)->assertUnprocessable();
        $this->withCredentials()->withCookie(LoginCodeService::COOKIE, $cookie)->postJson('/api/v1/auth/login', ['password' => 'wrong'] + $credentials, self::SPA)->assertUnprocessable();
        $this->withCredentials()->withCookie(LoginCodeService::COOKIE, $cookie)->postJson('/api/v1/auth/login', $credentials, self::SPA)->assertOk();
    }

    /** S6: "sign out everywhere" ends the app phones, tokens and other browsers; this browser stays. */
    public function test_sign_out_everywhere(): void
    {
        $owner = $this->staff($this->restaurant(), RoleSlug::Owner, ['email' => 'otto@example.com']);
        $token = $owner->createToken('Integration', ['vouchers.view']);
        $this->actingAs($owner, 'web');

        $this->postJson('/api/v1/auth/logout-everywhere', [], self::SPA)->assertOk();
        $this->assertNotNull(PersonalAccessToken::query()->whereKey($token->accessToken->getKey())->value('revoked_at'));
        $this->assertNotNull($owner->refresh()->sessions_revoked_at);
        $this->assertDatabaseHas('audit_logs', ['action' => 'auth.access_revoked', 'auditable_id' => $owner->id]);
    }

    /** T9: no name, no e-mail address in its place; T4: "Loyalty", not "Geschenk des Hauses". */
    public function test_guest_e_mails_greet_without_a_name_and_call_loyalty_loyalty(): void
    {
        Mail::fake();
        $this->actingAsStaff($this->restaurant(['locale' => 'de-AT']), RoleSlug::Owner);
        $this->postJson('/api/v1/vouchers', [
            'value' => 3000, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Regular'], 'customer' => ['email' => 'anna@example.com'],
        ], $this->idempotency())->assertCreated();

        Mail::assertSent(TemplatedMail::class, function (TemplatedMail $mail): bool {
            $text = $mail->textBody;
            $this->assertStringStartsWith("Hallo,\n", $text);
            $this->assertStringNotContainsString('anna@example.com', $text);
            $this->assertStringContainsString('Zahlungsart: Loyalty', $text);
            $this->assertStringNotContainsString('Geschenk des Hauses', $text);

            return true;
        });
    }

    /** L6/Q8: "sold" counts paid sales that stand; a closed voucher is not edited any more. */
    public function test_sold_counts_paid_sales_that_stand_and_closed_vouchers_stay_as_they_were(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment()], $this->idempotency())->assertCreated();
        $cancelled = (string) $this->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment()], $this->idempotency())->json('data.id');
        $this->postJson("/api/v1/vouchers/{$cancelled}/cancellation", ['reason' => 'wrong amount'], $this->idempotency())->assertSuccessful();
        $this->asTenant($restaurant, fn () => app(VoucherService::class)->sell(new Actor($owner), new IssueVoucherData(
            value: 1000, payment: new PaymentData(PaymentMethod::Complimentary, reason: 'Regular'), idempotencyKey: (string) Str::uuid(),
        )));

        $this->getJson('/api/v1/dashboard/stats')->assertOk()->assertJsonPath('data.vouchers_sold', 1)->assertJsonPath('data.vouchers_sold_this_month', 1);
        $this->patchJson("/api/v1/vouchers/{$cancelled}", ['recipient_name' => 'Someone else'])->assertStatus(409)->assertJsonPath('context.reason', 'closed');
    }

    /** L7: a new manager comes back as "not allowed to give loyalty", not as nothing. */
    public function test_a_new_manager_is_not_allowed_loyalty_from_the_start(): void
    {
        $this->actingAsStaff($this->restaurant(), RoleSlug::Owner);
        $this->postJson('/api/v1/users', ['name' => 'Mia', 'email' => 'mia@example.com', 'role' => 'manager'])->assertCreated()->assertJsonPath('data.can_give_loyalty', false);
    }
}
