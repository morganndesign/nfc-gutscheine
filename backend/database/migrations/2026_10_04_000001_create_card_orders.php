<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A restaurant asks the platform for new cards (app or dashboard); the platform accepts it, which orders a batch,
 * or declines it with a reason.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('card_orders', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained('restaurants')->cascadeOnDelete();
            $table->foreignUuid('requested_by')->nullable()->constrained('users')->nullOnDelete();
            $table->unsignedInteger('quantity');
            $table->string('note', 500)->nullable();
            $table->string('status', 16)->default('requested');
            $table->foreignUuid('card_batch_id')->nullable()->constrained('card_batches')->nullOnDelete();
            $table->foreignUuid('decided_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('decided_at')->nullable();
            $table->string('decline_reason', 500)->nullable();
            $table->timestamps();
            $table->index(['status', 'created_at']);
            $table->index(['restaurant_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('card_orders');
    }
};
