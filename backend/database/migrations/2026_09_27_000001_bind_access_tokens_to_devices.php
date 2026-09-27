<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tokens issued to the native waiter app are bound to the device that signed in. A bound token is only
 * accepted together with that device's X-Device-Id and stops working when the device is revoked.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table): void {
            $table->foreignUuid('device_id')->nullable()->after('restaurant_id')->constrained('devices')->nullOnDelete();
            $table->index(['tokenable_id', 'device_id', 'revoked_at']);
        });
    }

    public function down(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table): void {
            $table->dropIndex(['tokenable_id', 'device_id', 'revoked_at']);
            $table->dropConstrainedForeignId('device_id');
        });
    }
};
