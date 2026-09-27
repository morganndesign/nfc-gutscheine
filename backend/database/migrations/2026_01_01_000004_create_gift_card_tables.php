<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('gift_cards', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('customer_id')->nullable()->constrained()->nullOnDelete();
            // Secure identifier written to the NFC tag / QR code (UUID v4, never sequential).
            $table->uuid('public_token')->unique();
            $table->string('card_number', 24);
            $table->string('status', 20)->index();
            $table->char('currency', 3);
            // All monetary values are stored in minor units (cents).
            $table->unsignedBigInteger('initial_value');
            $table->unsignedBigInteger('balance');
            $table->unsignedBigInteger('total_loaded')->default(0);
            $table->unsignedBigInteger('total_redeemed')->default(0);
            $table->timestamp('expires_at')->nullable()->index();
            $table->timestamp('activated_at')->nullable();
            $table->timestamp('redeemed_at')->nullable();
            $table->timestamp('blocked_at')->nullable();
            $table->string('blocked_reason', 500)->nullable();
            $table->timestamp('expired_at')->nullable();
            $table->foreignUuid('replaced_by_id')->nullable()->constrained('gift_cards')->nullOnDelete();
            $table->foreignUuid('replaces_id')->nullable()->constrained('gift_cards')->nullOnDelete();
            $table->foreignUuid('issued_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('recipient_name', 160)->nullable();
            $table->text('notes')->nullable();
            // NFC binding
            $table->string('nfc_tag_type', 20)->nullable();
            $table->string('nfc_uid', 32)->nullable();
            $table->timestamp('nfc_written_at')->nullable();
            $table->boolean('nfc_locked')->default(false);
            $table->unsignedInteger('nfc_read_counter')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['restaurant_id', 'card_number']);
            $table->index(['restaurant_id', 'status', 'created_at']);
            $table->index(['restaurant_id', 'nfc_uid']);
        });

        Schema::create('gift_card_transactions', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('gift_card_id')->constrained()->restrictOnDelete();
            $table->string('type', 30);
            // Signed movement in minor units: positive = credit, negative = debit.
            $table->bigInteger('amount');
            $table->unsignedBigInteger('balance_before');
            $table->unsignedBigInteger('balance_after');
            $table->char('currency', 3);
            $table->string('idempotency_key', 100)->nullable();
            $table->string('reference', 120)->nullable();
            $table->string('note', 500)->nullable();
            $table->foreignUuid('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('related_transaction_id')->nullable()->constrained('gift_card_transactions')->nullOnDelete();
            $table->foreignUuid('counterparty_card_id')->nullable()->constrained('gift_cards')->nullOnDelete();
            $table->timestamp('reversed_at')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->timestamp('created_at', 6)->useCurrent();

            $table->unique(['restaurant_id', 'idempotency_key']);
            $table->index(['restaurant_id', 'created_at']);
            $table->index(['restaurant_id', 'type', 'created_at']);
            $table->index(['gift_card_id', 'created_at']);
        });

        Schema::create('nfc_scans', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('gift_card_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained()->nullOnDelete();
            $table->string('method', 20);
            $table->string('result', 40)->index();
            $table->string('nfc_uid', 32)->nullable();
            $table->unsignedInteger('read_counter')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->string('user_agent', 500)->nullable();
            $table->timestamp('created_at')->useCurrent()->index();
            $table->index(['restaurant_id', 'result', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('nfc_scans');
        Schema::dropIfExists('gift_card_transactions');
        Schema::dropIfExists('gift_cards');
    }
};
