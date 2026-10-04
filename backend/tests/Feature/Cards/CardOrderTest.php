<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Enums\CardBatchStatus;
use App\Enums\RoleSlug;
use App\Models\AuditLog;
use App\Models\CardBatch;
use App\Models\CardOrder;
use App\Models\User;
use Illuminate\Mail\Events\MessageSent;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * Restaurants order cards from the platform in the app or the dashboard (decision 2026-10-04): managers and owners
 * ask, the platform accepts (a batch is ordered) or declines with a reason.
 */
final class CardOrderTest extends TestCase
{
    use WithCards;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    public function test_a_manager_orders_cards_and_the_platform_is_told(): void
    {
        $admin = User::factory()->platformAdmin()->create(['email' => 'ops@giftcardpro.test', 'locale' => 'de']);
        $sent = [];
        Event::listen(MessageSent::class, static function (MessageSent $m) use (&$sent): void {
            $sent[] = $m->message;
        });
        $restaurant = $this->restaurant(['name' => 'Trattoria Test']);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson('/api/v1/card-orders', ['quantity' => 50, 'note' => ' Bitte bis Freitag '])->assertCreated()
            ->assertJsonPath('data.quantity', 50)
            ->assertJsonPath('data.note', 'Bitte bis Freitag')
            ->assertJsonPath('data.status', 'requested')
            ->assertJsonPath('data.batch_code', null);

        $this->getJson('/api/v1/card-orders')->assertOk()->assertJsonCount(1, 'data');
        $this->assertSame(1, AuditLog::query()->withoutGlobalScopes()->where('action', 'card.order_requested')->count());
        $this->assertCount(1, $sent);
        $mail = $sent[0];
        $this->assertSame('ops@giftcardpro.test', $mail->getTo()[0]->getAddress());
        $this->assertSame('[GiftCard Pro] Kartenbestellung: Trattoria Test · 50 Karten', $mail->getSubject());
        $this->assertStringContainsString('Bitte bis Freitag', (string) $mail->getTextBody());
        $this->assertSame($admin->email, $mail->getTo()[0]->getAddress());
    }

    public function test_the_waiter_app_orders_cards_with_its_phone_token(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Manager, ['email' => 'mia@example.com']);
        $device = 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff';
        $token = (string) $this->postJson('/api/v1/auth/token', [
            'email' => 'mia@example.com', 'password' => 'Password123!', 'device_id' => $device, 'device_name' => 'iPhone', 'platform' => 'ios',
        ])->assertCreated()->json('data.token');
        $this->app['auth']->forgetGuards();
        $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => $device]);

        $this->postJson('/api/v1/card-orders', ['quantity' => 30])->assertCreated();
        $this->getJson('/api/v1/card-orders')->assertOk()->assertJsonPath('data.0.quantity', 30)->assertJsonPath('data.0.requested_by', fn (?string $n): bool => $n !== null);
    }

    public function test_waiters_cannot_order_and_quantities_are_bounded(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $this->postJson('/api/v1/card-orders', ['quantity' => 10])->assertForbidden();

        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        foreach ([0, 1001, '10', null] as $quantity) {
            $this->postJson('/api/v1/card-orders', ['quantity' => $quantity])->assertUnprocessable();
        }
        $this->assertSame(0, CardOrder::query()->withoutGlobalScopes()->count());
    }

    public function test_at_most_three_orders_are_open_at_once(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        foreach ([10, 20, 30] as $quantity) {
            $this->postJson('/api/v1/card-orders', ['quantity' => $quantity])->assertCreated();
        }
        $this->postJson('/api/v1/card-orders', ['quantity' => 40])->assertUnprocessable()
            ->assertJsonPath('code', 'CARD_ORDER_NOT_POSSIBLE')
            ->assertJsonPath('context.reason', 'too_many_open');
    }

    public function test_a_restaurant_sees_only_its_own_orders_and_never_the_platform_list(): void
    {
        Mail::fake();
        $a = $this->restaurant();
        $b = $this->restaurant();
        $this->actingAsStaff($a, RoleSlug::Owner);
        $this->postJson('/api/v1/card-orders', ['quantity' => 10])->assertCreated();
        $this->actingAsStaff($b, RoleSlug::Owner);
        $this->getJson('/api/v1/card-orders')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/admin/card-orders')->assertForbidden();
        $order = CardOrder::query()->withoutGlobalScopes()->sole();
        $this->postJson("/api/v1/admin/card-orders/{$order->id}/accept")->assertForbidden();
    }

    public function test_the_platform_accepts_an_order_once_and_a_batch_is_ordered(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $id = (string) $this->postJson('/api/v1/card-orders', ['quantity' => 25])->assertCreated()->json('data.id');

        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);
        $this->getJson('/api/v1/admin/card-orders')->assertOk()
            ->assertJsonPath('data.0.id', $id)
            ->assertJsonPath('data.0.restaurant.name', $restaurant->name);
        $accepted = $this->postJson("/api/v1/admin/card-orders/{$id}/accept", ['manufacturer' => ''])->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $batch = CardBatch::query()->withoutGlobalScopes()->where('batch_code', $accepted->json('data.batch_code'))->sole();
        $this->assertSame($restaurant->id, $batch->restaurant_id);
        $this->assertSame(25, $batch->quantity_ordered);
        $this->assertSame(CardBatchStatus::InProduction, $batch->status);
        $this->assertSame('in-house', $batch->manufacturer);

        // A second click (two tabs) orders nothing more.
        $this->postJson("/api/v1/admin/card-orders/{$id}/accept")->assertStatus(409)->assertJsonPath('context.reason', 'already_decided');
        $this->postJson("/api/v1/admin/card-orders/{$id}/decline", ['reason' => 'too late'])->assertStatus(409);
        $this->assertSame(1, CardBatch::query()->withoutGlobalScopes()->count());
    }

    public function test_a_declined_order_tells_the_restaurant_why(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $id = (string) $this->postJson('/api/v1/card-orders', ['quantity' => 500])->assertCreated()->json('data.id');

        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);
        $this->postJson("/api/v1/admin/card-orders/{$id}/decline", ['reason' => ''])->assertUnprocessable();
        $this->postJson("/api/v1/admin/card-orders/{$id}/decline", ['reason' => 'Bitte 100 Stück, wie besprochen.'])->assertOk();

        Sanctum::actingAs($owner, ['*']);
        $this->getJson('/api/v1/card-orders')->assertOk()
            ->assertJsonPath('data.0.status', 'declined')
            ->assertJsonPath('data.0.decline_reason', 'Bitte 100 Stück, wie besprochen.');
        $this->assertSame(0, CardBatch::query()->withoutGlobalScopes()->count());
    }
}
