<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Dashboard sign-in with a 6-digit code by e-mail (decision 2026-10-05): after the password, a browser that is not
 * trusted gets a code; after the code it is trusted for 15 days. Only hashes are stored.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('login_codes', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->char('code_hash', 64);
            $table->boolean('remember')->default(false);
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->unsignedTinyInteger('sends')->default(1);
            $table->timestamp('sent_at');
            $table->timestamp('expires_at');
            $table->timestamp('used_at')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'created_at']);
        });

        Schema::create('trusted_browsers', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->char('secret_hash', 64);
            $table->string('user_agent', 500)->nullable();
            $table->timestamp('expires_at');
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trusted_browsers');
        Schema::dropIfExists('login_codes');
    }
};
