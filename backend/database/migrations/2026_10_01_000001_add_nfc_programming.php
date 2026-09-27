<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * NFC programming v2.
 *
 * - `nfc_uid_active` is a generated column: the chip UID while the card can still be used (not deleted,
 *   replaced or expired), otherwise NULL. Its UNIQUE index makes it impossible, even under concurrency,
 *   for one physical chip to be linked to two usable cards on the whole platform. Replaced / expired
 *   cards keep their `nfc_uid` for history and release the chip automatically.
 * - `nfc_verified_at`: set only when the dashboard read the tag back and the URL matched exactly.
 * - `nfc_write_attempts`: one row per programming attempt (success, refusal and failure).
 */
return new class extends Migration
{
    private const ACTIVE_UID = "CASE WHEN deleted_at IS NULL AND status NOT IN ('replaced', 'expired') THEN nfc_uid ELSE NULL END";

    public function up(): void
    {
        $duplicates = DB::table('gift_cards')
            ->select('nfc_uid')
            ->whereNotNull('nfc_uid')
            ->whereNull('deleted_at')
            ->whereNotIn('status', ['replaced', 'expired'])
            ->groupBy('nfc_uid')
            ->havingRaw('COUNT(*) > 1')
            ->pluck('nfc_uid');

        if ($duplicates->isNotEmpty()) {
            throw new RuntimeException(
                'Cannot add the unique NFC UID constraint: these chip UIDs are linked to more than one usable card: '
                .$duplicates->implode(', ').'. Re-program or unlink the affected cards first.'
            );
        }

        Schema::table('gift_cards', function (Blueprint $table): void {
            $table->timestamp('nfc_verified_at')->nullable()->after('nfc_written_at');
            $table->string('nfc_uid_active', 32)->nullable()->virtualAs(self::ACTIVE_UID);
        });

        Schema::table('gift_cards', function (Blueprint $table): void {
            $table->unique('nfc_uid_active', 'gift_cards_nfc_uid_active_unique');
        });

        Schema::create('nfc_write_attempts', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('gift_card_id')->constrained('gift_cards')->cascadeOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained('devices')->nullOnDelete();
            /** Client-generated id that ties the steps of one attempt together (check → bind / failure). */
            $table->uuid('attempt_id')->unique();
            $table->string('method', 20);
            $table->string('stage', 20);
            $table->string('result', 20);
            $table->string('error_code', 64)->nullable();
            $table->string('error_message', 255)->nullable();
            $table->string('uid', 32)->nullable();
            $table->string('tag_type', 20)->nullable();
            $table->string('previous_url', 512)->nullable();
            $table->string('read_back_url', 512)->nullable();
            $table->string('conflict_card_id', 36)->nullable();
            $table->boolean('locked')->default(false);
            $table->string('user_agent', 255)->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['restaurant_id', 'created_at']);
            $table->index(['gift_card_id', 'created_at']);
            $table->index(['restaurant_id', 'result']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('nfc_write_attempts');

        Schema::table('gift_cards', function (Blueprint $table): void {
            $table->dropUnique('gift_cards_nfc_uid_active_unique');
        });

        Schema::table('gift_cards', function (Blueprint $table): void {
            $table->dropColumn(['nfc_uid_active', 'nfc_verified_at']);
        });
    }
};
