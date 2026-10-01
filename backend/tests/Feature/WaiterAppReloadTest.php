<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Enums\TransactionType;
use App\Models\Card;
use App\Models\Restaurant;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\Ntag424Chip;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * Topping up a guest's card in GiftCard Waiter: a manager or owner taps the card (purpose `reload`), enters the
 * amount and books the payment. The till never tops up a card it has not just seen; waiters cannot top up.
 */
final class WaiterAppReloadTest extends TestCase
{
    use WithCards;

    private const DEVICE = 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff';

    private Restaurant $restaurant;

    private Card $card;

    private Voucher $voucher;

    private Ntag424Chip $chip;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->restaurant = $this->restaurant();
        [$this->card, $this->voucher] = $this->activeCardVoucher($this->restaurant, 2000);
        $this->chip = $this->chip($this->card);
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    private function signInApp(RoleSlug $role, string $email): void
    {
        $this->staff($this->restaurant, $role, ['email' => $email]);
        $token = (string) $this->withHeaders(['User-Agent' => 'GiftCardWaiter/2.0.1 (Android 14; Pixel 7)'])
            ->postJson('/api/v1/auth/token', [
                'email' => $email,
                'password' => 'Password123!',
                'device_id' => self::DEVICE,
                'device_name' => 'Pixel 7',
                'platform' => 'android',
            ])->assertCreated()->json('data.token');
        $this->app['auth']->forgetGuards();
        $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => self::DEVICE]);
    }

    /** @param  array<string, mixed>  $extra */
    private function reload(string $voucherId, ?string $presentmentId, int $amount = 3000, array $extra = [], ?string $key = null): TestResponse
    {
        return $this->postJson("/api/v1/vouchers/{$voucherId}/reloads", [
            'amount' => $amount,
            'payment' => ['method' => 'cash'],
            'presentment_id' => $presentmentId,
            ...$extra,
        ], $this->idempotency($key));
    }

    public function test_a_manager_taps_the_card_and_tops_it_up(): void
    {
        $this->signInApp(RoleSlug::Manager, 'mia@example.com');

        $tap = $this->tapCard($this->chip, 'reload')->assertCreated()
            ->assertJsonPath('data.voucher.id', $this->voucher->id)
            ->assertJsonPath('data.voucher.balance', 2000);
        $key = (string) Str::uuid();

        $this->reload($this->voucher->id, (string) $tap->json('data.id'), key: $key)->assertCreated()
            ->assertJsonPath('data.voucher.balance', 5000)
            ->assertJsonPath('replayed', false);
        // A lost answer is retried with the same key: one booking.
        $this->reload($this->voucher->id, (string) $tap->json('data.id'), key: $key)->assertOk()->assertJsonPath('replayed', true);

        $this->assertSame(5000, $this->voucher->refresh()->balance);
        $tx = VoucherTransaction::query()->where('voucher_id', $this->voucher->id)->where('type', TransactionType::Reload->value)->sole();
        $this->assertSame((string) $tap->json('data.id'), $tx->presentment_id);
        $this->assertLedgerConsistent($this->voucher);
    }

    public function test_an_owner_tops_up_by_card_terminal_with_a_reference(): void
    {
        $this->signInApp(RoleSlug::Owner, 'otto@example.com');
        $tap = (string) $this->tapCard($this->chip, 'reload')->assertCreated()->json('data.id');

        $this->reload($this->voucher->id, $tap, 1500, ['payment' => ['method' => 'card_terminal', 'reference' => 'TID-4711']])
            ->assertCreated()->assertJsonPath('data.transaction.payment.method', 'card_terminal');
        $this->assertSame(3500, $this->voucher->refresh()->balance);
    }

    public function test_a_waiter_can_neither_tap_for_a_reload_nor_reload(): void
    {
        $this->signInApp(RoleSlug::Waiter, 'anna@example.com');

        $this->tapCard($this->chip, 'reload')->assertForbidden();
        $spend = (string) $this->tapCard($this->chip)->assertCreated()->json('data.id');
        $this->reload($this->voucher->id, $spend)->assertForbidden();
        $this->assertSame(2000, $this->voucher->refresh()->balance);
    }

    public function test_the_ticket_must_be_a_fresh_reload_tap_of_this_card(): void
    {
        [, $other] = $this->activeCardVoucher($this->restaurant, 1000);
        $this->signInApp(RoleSlug::Manager, 'mia@example.com');

        // Without a tap, with a spend tap, with another card's tap, with a used tap.
        $this->reload($this->voucher->id, null)->assertStatus(422)->assertJsonPath('context.reason', 'not_found');
        $spend = (string) $this->tapCard($this->chip)->assertCreated()->json('data.id');
        $this->reload($this->voucher->id, $spend)->assertStatus(422)->assertJsonPath('context.reason', 'wrong_purpose');
        $tap = (string) $this->tapCard($this->chip, 'reload')->assertCreated()->json('data.id');
        $this->reload($other->id, $tap)->assertStatus(422)->assertJsonPath('context.reason', 'wrong_voucher');
        $this->reload($this->voucher->id, $tap)->assertCreated();
        $this->reload($this->voucher->id, $tap)->assertStatus(422)->assertJsonPath('context.reason', 'already_used');

        $this->assertSame(5000, $this->voucher->refresh()->balance);
        $this->assertSame(1000, $other->refresh()->balance);
    }

    public function test_limits_still_apply_and_a_suspended_card_is_not_topped_up(): void
    {
        $this->restaurant->settings->forceFill(['max_voucher_balance' => 4000])->save();
        $this->signInApp(RoleSlug::Manager, 'mia@example.com');

        $tap = (string) $this->tapCard($this->chip, 'reload')->assertCreated()->json('data.id');
        $this->reload($this->voucher->id, $tap)->assertStatus(422)->assertJsonPath('code', 'BALANCE_LIMIT_EXCEEDED');

        $tap = (string) $this->tapCard($this->chip, 'reload')->assertCreated()->json('data.id');
        $this->postJson("/api/v1/cards/{$this->card->card_number}/suspend", ['reason' => 'guest reported it lost'])->assertOk();
        $this->reload($this->voucher->id, $tap, 1000)->assertStatus(422)->assertJsonPath('context.reason', 'card_not_active');
        $this->assertSame(2000, $this->voucher->refresh()->balance);
    }

    public function test_the_dashboard_still_reloads_without_a_tap(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $this->reload($this->voucher->id, null, 500)->assertCreated()->assertJsonPath('data.voucher.balance', 2500);
    }
}
