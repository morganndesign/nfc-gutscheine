<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Indexes for two lists that otherwise sort a whole ever-growing table on every page load: the platform audit log
 * (newest first, all restaurants) and the invitation state of staff (last invitation e-mail per address).
 * Adding an index changes no row, so the append-only triggers on audit_logs are not involved.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('audit_logs', function (Blueprint $table): void {
            $table->index('created_at');
        });
        Schema::table('notification_logs', function (Blueprint $table): void {
            $table->index(['recipient', 'template_key']);
        });
    }

    public function down(): void
    {
        Schema::table('notification_logs', function (Blueprint $table): void {
            $table->dropIndex(['recipient', 'template_key']);
        });
        Schema::table('audit_logs', function (Blueprint $table): void {
            $table->dropIndex(['created_at']);
        });
    }
};
