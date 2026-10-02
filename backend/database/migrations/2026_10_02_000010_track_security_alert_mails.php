<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * When the e-mail about a high or critical security alert reached operations. An alert raised while the mail server
 * was down stays without it, and the monitor mails it on a later run instead of never.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('security_alerts', function (Blueprint $table): void {
            $table->timestamp('notified_at')->nullable();
        });
        // Alerts from before this column were handled when they were raised: no burst of old alerts on deploy.
        DB::table('security_alerts')->update(['notified_at' => DB::raw('created_at')]);
    }

    public function down(): void
    {
        Schema::table('security_alerts', function (Blueprint $table): void {
            $table->dropColumn('notified_at');
        });
    }
};
