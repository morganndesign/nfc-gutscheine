<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('devices', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('registered_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('name', 120);
            $table->string('type', 30)->default('phone');
            $table->string('fingerprint', 64);
            $table->string('platform', 120)->nullable();
            $table->string('status', 20)->default('active');
            $table->timestamp('last_seen_at')->nullable();
            $table->string('last_ip', 45)->nullable();
            $table->foreignUuid('last_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('revoked_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['restaurant_id', 'fingerprint']);
        });

        Schema::create('personal_access_tokens', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuidMorphs('tokenable');
            $table->foreignUuid('restaurant_id')->nullable()->index();
            // Waiter app tokens are bound to the device that signed in (X-Device-Id) and die with it.
            $table->foreignUuid('device_id')->nullable()->constrained('devices')->nullOnDelete();
            $table->string('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->string('last_used_ip', 45)->nullable();
            $table->timestamp('expires_at')->nullable()->index();
            $table->timestamp('revoked_at')->nullable();
            $table->foreignUuid('revoked_by')->nullable();
            $table->timestamps();
            $table->index(['tokenable_id', 'device_id', 'revoked_at']);
        });

        Schema::create('customers', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->string('first_name', 100)->nullable();
            $table->string('last_name', 100)->nullable();
            $table->string('email', 191)->nullable();
            $table->string('phone', 40)->nullable();
            $table->text('notes')->nullable();
            $table->boolean('marketing_consent')->default(false);
            $table->timestamp('anonymized_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->index(['restaurant_id', 'email']);
            $table->index(['restaurant_id', 'last_name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customers');
        Schema::dropIfExists('personal_access_tokens');
        Schema::dropIfExists('devices');
    }
};
