<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Customer;
use App\Models\Device;
use Tests\TestCase;

/**
 * One restaurant must never be able to see or touch another restaurant's data.
 */
final class TenantIsolationTest extends TestCase
{
    public function test_vouchers_of_other_restaurants_are_invisible(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $myVoucher = $this->issueVoucher($mine);
        $foreign = $this->sell($theirs);

        $this->actingAsStaff($mine, RoleSlug::Owner);

        $this->getJson('/api/v1/vouchers')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $myVoucher->id);

        $id = $foreign->voucher->id;
        $this->getJson("/api/v1/vouchers/{$id}")->assertNotFound();
        $this->patchJson("/api/v1/vouchers/{$id}", ['notes' => 'hacked'])->assertNotFound();
        $this->postJson("/api/v1/vouchers/{$id}/redemptions", ['amount' => 100, 'presentment_id' => $myVoucher->id], $this->idempotency())->assertNotFound();
        $this->postJson("/api/v1/vouchers/{$id}/reloads", ['amount' => 100, 'payment' => $this->cashPayment()], $this->idempotency())->assertNotFound();
        $this->postJson("/api/v1/vouchers/{$id}/block", ['reason' => 'test'])->assertNotFound();
        $this->getJson("/api/v1/vouchers/{$id}/history")->assertNotFound();
        $this->getJson("/api/v1/transactions/{$foreign->transaction->id}")->assertNotFound();
        $this->postJson("/api/v1/transactions/{$foreign->transaction->id}/reverse", ['reason' => 'test'])->assertNotFound();
    }

    public function test_a_foreign_voucher_qr_is_not_recognized_and_logged(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $foreign = $this->sell($theirs);

        $this->actingAsStaff($mine, RoleSlug::Waiter);

        $this->present($foreign->printable->payload)
            ->assertStatus(422)
            ->assertJsonPath('code', 'MEDIUM_NOT_RECOGNIZED')
            ->assertJsonMissingPath('data');

        $this->assertDatabaseHas('audit_logs', ['restaurant_id' => $mine->id, 'action' => 'presentment.failed']);
    }

    public function test_customers_and_users_are_isolated(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $foreignCustomer = Customer::factory()->create(['restaurant_id' => $theirs->id]);
        $foreignUser = $this->staff($theirs, RoleSlug::Waiter);

        $this->actingAsStaff($mine, RoleSlug::Owner);

        $this->getJson("/api/v1/customers/{$foreignCustomer->id}")->assertNotFound();
        $this->getJson('/api/v1/customers')->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/users/{$foreignUser->id}")->assertNotFound();
        $this->postJson("/api/v1/users/{$foreignUser->id}/deactivate")->assertNotFound();

        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer_id' => $foreignCustomer->id], $this->idempotency())
            ->assertStatus(422)->assertJsonValidationErrors('customer_id');
    }

    public function test_restaurant_id_in_body_or_query_cannot_cross_tenants(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $theirVoucher = $this->issueVoucher($theirs);

        $this->actingAsStaff($mine, RoleSlug::Owner);

        // A forged restaurant_id in the body is ignored: the row is stamped with the caller's tenant.
        $created = $this->postJson('/api/v1/customers', [
            'first_name' => 'Planted', 'last_name' => 'Row', 'restaurant_id' => $theirs->id,
        ])->assertCreated()->json('data.id');
        $this->assertDatabaseHas('customers', ['id' => $created, 'restaurant_id' => $mine->id]);
        $this->assertDatabaseMissing('customers', ['id' => $created, 'restaurant_id' => $theirs->id]);

        // A restaurant_id filter on a scoped index cannot widen the scope: only the caller's rows come back.
        $this->getJson('/api/v1/vouchers?restaurant_id='.$theirs->id)
            ->assertOk()
            ->assertJsonMissing(['id' => $theirVoucher->id]);
    }

    public function test_devices_of_other_restaurants_are_isolated(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $foreignDevice = Device::factory()->create(['restaurant_id' => $theirs->id]);

        $this->actingAsStaff($mine, RoleSlug::Owner);

        $this->getJson('/api/v1/devices')->assertOk()->assertJsonMissing(['id' => $foreignDevice->id]);
        $this->patchJson("/api/v1/devices/{$foreignDevice->id}", ['name' => 'hijacked'])->assertNotFound();
        $this->postJson("/api/v1/devices/{$foreignDevice->id}/revoke")->assertNotFound();
        $this->postJson("/api/v1/devices/{$foreignDevice->id}/restore")->assertNotFound();
    }

    public function test_idempotency_keys_are_scoped_per_restaurant(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $key = $this->idempotency();
        $body = ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment()];

        $this->actingAsStaff($theirs, RoleSlug::Manager);
        $foreignId = $this->postJson('/api/v1/vouchers', $body, $key)->assertCreated()->json('data.id');

        $this->actingAsStaff($mine, RoleSlug::Manager);
        $mineId = $this->postJson('/api/v1/vouchers', $body, $key)->assertCreated()->assertJsonPath('replayed', false)->json('data.id');
        $this->assertNotSame($foreignId, $mineId);
    }
}
