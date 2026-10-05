<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The waiter app signs in with the e-mailed code too (decision 2026-10-06), bound to the phone that asked for it,
 * and again after every app update: a token remembers the app version it was issued to. An e-mail change ends the
 * person's browser sessions (audit S4).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('login_codes', function (Blueprint $table): void {
            $table->string('client', 10)->default('web')->after('user_id');
            $table->string('device_id', 64)->nullable()->after('client');
        });
        Schema::table('personal_access_tokens', function (Blueprint $table): void {
            $table->string('app_version', 20)->nullable()->after('device_id');
        });
        // Browser sessions signed in before this moment end (e-mail change, deactivation; audit S4).
        Schema::table('users', function (Blueprint $table): void {
            $table->timestamp('sessions_revoked_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('login_codes', function (Blueprint $table): void {
            $table->dropColumn(['client', 'device_id']);
        });
        Schema::table('personal_access_tokens', function (Blueprint $table): void {
            $table->dropColumn('app_version');
        });
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('sessions_revoked_at');
        });
    }
};
