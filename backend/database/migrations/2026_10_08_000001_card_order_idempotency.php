<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** A card order repeated after a lost answer is the same order (audit K5). */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('card_orders', function (Blueprint $table): void {
            $table->string('idempotency_key', 96)->nullable();
            $table->unique(['restaurant_id', 'idempotency_key']);
        });
    }

    public function down(): void
    {
        Schema::table('card_orders', function (Blueprint $table): void {
            $table->dropUnique(['restaurant_id', 'idempotency_key']);
            $table->dropColumn('idempotency_key');
        });
    }
};
