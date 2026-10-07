<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * POS partners (decision 2026-10-07): a till system redeems vouchers and gift cards inside its own app. GiftCard Pro
 * gives the POS company one partner key; each restaurant connects itself with a one-time code from its dashboard.
 * Every till of that POS becomes a device of the restaurant (type `pos`), revocable like a waiter phone.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partners', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name', 120);
            $table->string('contact_email', 254)->nullable();
            // The key is shown once; only its hash is kept. The prefix identifies it in lists ("gcpp_ab12…").
            $table->char('key_hash', 64)->unique();
            $table->string('key_prefix', 16);
            $table->string('status', 20)->default('active');
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
        });

        Schema::create('partner_connections', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('partner_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('restaurant_id')->constrained()->cascadeOnDelete();
            $table->string('status', 20)->default('active');
            $table->foreignUuid('connected_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('connected_at');
            $table->foreignUuid('revoked_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('revoked_at')->nullable();
            $table->timestamps();
            $table->unique(['partner_id', 'restaurant_id']);
        });

        // A one-time code the owner creates and gives to the POS company (valid 24 hours, single use).
        Schema::create('partner_link_codes', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->cascadeOnDelete();
            $table->char('code_hash', 64)->unique();
            $table->foreignUuid('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('expires_at');
            $table->timestamp('used_at')->nullable();
            $table->foreignUuid('used_by_partner_id')->nullable()->constrained('partners')->nullOnDelete();
            $table->timestamps();
        });

        Schema::table('devices', function (Blueprint $table): void {
            $table->foreignUuid('partner_connection_id')->nullable()->after('registered_by')->constrained()->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('devices', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('partner_connection_id');
        });
        Schema::dropIfExists('partner_link_codes');
        Schema::dropIfExists('partner_connections');
        Schema::dropIfExists('partners');
    }
};
