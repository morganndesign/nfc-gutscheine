<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Online sales (decision 2026-10-06): each restaurant sells vouchers in its own shop; the guest pays the restaurant
 * through its connected payment provider account (Stripe Connect, direct charges). Only the provider's verified
 * webhook creates a voucher.
 */
return new class extends Migration
{
    public function up(): void
    {
        // The restaurant's account at the payment provider: only its id, never a key.
        Schema::create('psp_accounts', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('provider', 20);
            $table->string('account_id', 64)->unique();
            $table->boolean('charges_enabled')->default(false);
            $table->boolean('payouts_enabled')->default(false);
            $table->boolean('details_submitted')->default(false);
            $table->foreignUuid('connected_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('enabled_at')->nullable();
            $table->timestamps();
        });

        Schema::create('online_shops', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->unique()->constrained()->cascadeOnDelete();
            $table->boolean('enabled')->default(false);
            /** @var list<int> Offered amounts in cents */
            $table->json('amounts');
            $table->boolean('custom_amount')->default(true);
            $table->unsignedInteger('max_amount');
            $table->boolean('card_pickup')->default(false);
            $table->string('headline', 120)->nullable();
            $table->string('intro', 600)->nullable();
            $table->string('terms_url', 500)->nullable();
            $table->string('imprint_url', 500)->nullable();
            $table->timestamps();
        });

        Schema::create('online_orders', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->cascadeOnDelete();
            $table->string('status', 20)->index();
            $table->unsignedInteger('amount');
            $table->char('currency', 3);
            $table->string('buyer_email', 254);
            $table->string('buyer_name', 120)->nullable();
            $table->string('recipient_name', 120)->nullable();
            $table->string('gift_message', 300)->nullable();
            $table->boolean('card_pickup')->default(false);
            $table->string('locale', 5);
            // Proves the buyer's own success page (the order id alone is not a secret).
            $table->string('status_token_hash', 64);
            $table->string('provider', 20);
            $table->string('account_id', 64);
            $table->string('checkout_id', 255)->nullable()->unique();
            $table->string('payment_id', 255)->nullable()->unique();
            $table->unsignedInteger('application_fee')->default(0);
            $table->foreignUuid('voucher_id')->nullable()->constrained()->nullOnDelete();
            $table->string('ip_hash', 64)->nullable();
            $table->timestamp('expires_at');
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('card_picked_up_at')->nullable();
            $table->timestamps();
            $table->index(['restaurant_id', 'created_at']);
            $table->index(['buyer_email', 'created_at']);
        });

        // Every provider event once (the provider retries until it gets a 2xx).
        Schema::create('webhook_events', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('provider', 20);
            $table->string('event_id', 255);
            $table->string('type', 100);
            $table->string('account_id', 64)->nullable();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();
            $table->unique(['provider', 'event_id']);
        });

        Schema::table('vouchers', function (Blueprint $table): void {
            $table->boolean('sold_online')->default(false)->index();
        });
    }

    public function down(): void
    {
        Schema::table('vouchers', function (Blueprint $table): void {
            $table->dropIndex(['sold_online']);
            $table->dropColumn('sold_online');
        });
        Schema::dropIfExists('webhook_events');
        Schema::dropIfExists('online_orders');
        Schema::dropIfExists('online_shops');
        Schema::dropIfExists('psp_accounts');
    }
};
