<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * POS partners, audit H1 (2026-10-07): each restaurant connection gets its own token (`gcpc_…`, only its hash is
 * kept). The tills of that restaurant use it; the POS company's partner key is needed only to connect restaurants.
 * A till taken from one restaurant then reveals nothing about the others, and a new partner key stops no till.
 * Connections made before this have no token: the partner issues one (POST /connections/{id}/token).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_connections', function (Blueprint $table): void {
            $table->char('token_hash', 64)->nullable()->unique()->after('status');
            $table->string('token_prefix', 16)->nullable()->after('token_hash');
        });
    }

    public function down(): void
    {
        Schema::table('partner_connections', function (Blueprint $table): void {
            $table->dropUnique(['token_hash']);
            $table->dropColumn(['token_hash', 'token_prefix']);
        });
    }
};
