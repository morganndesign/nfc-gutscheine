<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_logs', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained()->nullOnDelete();
            $table->string('action', 80)->index();
            $table->string('auditable_type', 80)->nullable();
            $table->uuid('auditable_id')->nullable();
            $table->json('old_values')->nullable();
            $table->json('new_values')->nullable();
            $table->json('metadata')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->string('user_agent', 500)->nullable();
            $table->string('request_id', 64)->nullable();
            $table->timestamp('created_at', 6)->useCurrent();
            $table->index(['auditable_type', 'auditable_id']);
            $table->index(['restaurant_id', 'created_at']);
        });

        Schema::create('notification_templates', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->nullable()->constrained()->restrictOnDelete();
            $table->string('key', 60);
            $table->string('channel', 20)->default('mail');
            $table->string('locale', 10)->default('en');
            $table->string('subject', 200);
            $table->text('body');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->unique(['restaurant_id', 'key', 'channel', 'locale'], 'notification_templates_scope_unique');
        });

        Schema::create('notification_logs', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('gift_card_id')->nullable()->constrained()->nullOnDelete();
            $table->string('template_key', 60);
            $table->string('channel', 20);
            $table->string('recipient', 191);
            $table->string('status', 20);
            $table->text('error')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_logs');
        Schema::dropIfExists('notification_templates');
        Schema::dropIfExists('audit_logs');
    }
};
