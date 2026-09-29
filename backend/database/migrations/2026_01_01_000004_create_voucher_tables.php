<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Vouchers, their presentation media, presentments, payments and the ledger (architecture §5, §10, §14).
 *
 * Financial history (ledger and payments) is append-only: foreign keys from these tables never cascade or
 * null out, and database triggers reject UPDATE and DELETE (migration 000007).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vouchers', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('customer_id')->nullable()->constrained()->nullOnDelete();
            // card | digital (decision 26): a voucher is spent either with its physical card or with its QR, never both.
            $table->string('kind', 10);
            // Internal voucher number: staff and support only, never printed, never a credential (decision 24).
            $table->string('voucher_number', 24);
            $table->string('status', 20)->index();
            $table->char('currency', 3);
            // All monetary values are stored in minor units (cents).
            $table->unsignedBigInteger('initial_value');
            $table->unsignedBigInteger('balance');
            $table->unsignedBigInteger('total_loaded')->default(0);
            $table->unsignedBigInteger('total_redeemed')->default(0);
            $table->timestamp('expires_at')->nullable()->index();
            $table->timestamp('blocked_at')->nullable();
            $table->string('blocked_reason', 500)->nullable();
            $table->timestamp('expired_at')->nullable();
            $table->foreignUuid('issued_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->string('recipient_name', 160)->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();

            $table->unique(['restaurant_id', 'voucher_number']);
            $table->index(['restaurant_id', 'status', 'created_at']);
        });

        Schema::create('media', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('voucher_id')->constrained()->restrictOnDelete();
            $table->string('type', 20);
            $table->string('role', 20);
            $table->string('status', 20);
            // SHA-256 of a 256-bit random secret. The secret itself is never stored.
            $table->char('secret_hash', 64)->nullable()->unique();
            $table->foreignUuid('created_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->timestamp('revoked_at')->nullable();
            $table->foreignUuid('revoked_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->string('revoke_reason', 500)->nullable();
            $table->timestamps();

            $table->index(['voucher_id', 'type', 'status']);
        });

        Schema::create('presentments', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            // Null for a card presented before it belongs to a voucher (receive, bind).
            $table->foreignUuid('voucher_id')->nullable()->constrained()->restrictOnDelete();
            $table->foreignUuid('medium_id')->nullable()->constrained('media')->restrictOnDelete();
            $table->string('purpose', 20);
            $table->string('method', 20);
            $table->string('level', 4);
            $table->string('status', 20);
            $table->foreignUuid('user_id')->nullable()->constrained()->restrictOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained()->restrictOnDelete();
            $table->timestamp('expires_at');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamp('created_at', 6)->useCurrent();

            $table->index(['restaurant_id', 'created_at']);
        });

        Schema::create('payments', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('voucher_id')->constrained()->restrictOnDelete();
            $table->string('method', 20);
            $table->unsignedBigInteger('amount');
            $table->char('currency', 3);
            // Terminal receipt number, bank reference or provider payment id.
            $table->string('reference', 120)->nullable();
            // Complimentary vouchers: who approved and why.
            $table->foreignUuid('approved_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->string('reason', 500)->nullable();
            $table->foreignUuid('received_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained()->restrictOnDelete();
            $table->timestamp('created_at', 6)->useCurrent();
            $this->chainColumns($table);

            $table->index(['restaurant_id', 'method', 'created_at']);
        });

        Schema::create('voucher_transactions', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('voucher_id')->constrained()->restrictOnDelete();
            $table->string('type', 20);
            // Signed movement in minor units: positive = credit, negative = debit.
            $table->bigInteger('amount');
            $table->unsignedBigInteger('balance_before');
            $table->unsignedBigInteger('balance_after');
            $table->char('currency', 3);
            $table->string('idempotency_key', 100)->nullable();
            // Every debit consumes exactly one presentment; a presentment can never pay twice.
            $table->foreignUuid('presentment_id')->nullable()->unique()->constrained()->restrictOnDelete();
            // Every sale and reload references the payment that funded it.
            $table->foreignUuid('payment_id')->nullable()->unique()->constrained()->restrictOnDelete();
            // A reversal points at its original; UNIQUE: an entry can be reversed at most once.
            $table->foreignUuid('related_transaction_id')->nullable()->unique()->constrained('voucher_transactions')->restrictOnDelete();
            $table->string('reference', 120)->nullable();
            $table->string('note', 500)->nullable();
            $table->foreignUuid('user_id')->nullable()->constrained()->restrictOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained()->restrictOnDelete();
            $table->string('ip_address', 45)->nullable();
            $table->timestamp('created_at', 6)->useCurrent();
            $this->chainColumns($table);

            $table->unique(['restaurant_id', 'idempotency_key']);
            $table->index(['restaurant_id', 'created_at']);
            $table->index(['restaurant_id', 'type', 'created_at']);
            $table->index(['voucher_id', 'created_at']);
        });

        // Head of every hash chain (ledger, payments, audit log; one chain per restaurant and table).
        Schema::create('chain_heads', function (Blueprint $table): void {
            $table->string('chain', 40);
            $table->string('scope', 36);
            $table->unsignedBigInteger('seq')->default(0);
            $table->char('head_hash', 64);
            $table->timestamp('updated_at')->nullable();
            $table->primary(['chain', 'scope']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chain_heads');
        Schema::dropIfExists('voucher_transactions');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('presentments');
        Schema::dropIfExists('media');
        Schema::dropIfExists('vouchers');
    }

    private function chainColumns(Blueprint $table): void
    {
        // Scope of the chain: the restaurant id, or "platform" for rows without a restaurant.
        $table->string('chain_scope', 36);
        $table->unsignedBigInteger('chain_seq');
        $table->char('prev_hash', 64);
        $table->char('entry_hash', 64);
        $table->unique(['chain_scope', 'chain_seq']);
    }
};
