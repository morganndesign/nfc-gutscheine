<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Durations measured by the dashboard for each programming attempt (milliseconds), so write, verification
 * and total times can be evaluated on real devices (docs/NFC.md, "Release test").
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('nfc_write_attempts', function (Blueprint $table): void {
            $table->unsignedInteger('detect_ms')->nullable()->after('locked');
            $table->unsignedInteger('write_ms')->nullable()->after('detect_ms');
            $table->unsignedInteger('verify_ms')->nullable()->after('write_ms');
            $table->unsignedInteger('total_ms')->nullable()->after('verify_ms');
        });
    }

    public function down(): void
    {
        Schema::table('nfc_write_attempts', function (Blueprint $table): void {
            $table->dropColumn(['detect_ms', 'write_ms', 'verify_ms', 'total_ms']);
        });
    }
};
