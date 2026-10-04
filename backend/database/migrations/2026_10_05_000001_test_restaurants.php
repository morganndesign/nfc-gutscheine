<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A test restaurant (decision 2026-10-05): the platform keeps one restaurant for its own tests, whose cards can be
 * put back into stock and sold again. A card then gets a new medium for every sale, so `media.card_id` is no
 * longer unique; one active medium per card stays guaranteed by the card lifecycle (only a stock card is bound,
 * under the card's row lock).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('restaurants', function (Blueprint $table): void {
            $table->boolean('is_test')->default(false)->after('status');
        });

        Schema::table('media', function (Blueprint $table): void {
            // The foreign key needs an index: add the plain one before the unique one goes.
            $table->index('card_id', 'media_card_id_index');
            $table->dropUnique('media_card_id_unique');
        });
    }

    public function down(): void
    {
        Schema::table('media', function (Blueprint $table): void {
            $table->unique('card_id', 'media_card_id_unique');
            $table->dropIndex('media_card_id_index');
        });

        Schema::table('restaurants', function (Blueprint $table): void {
            $table->dropColumn('is_test');
        });
    }
};
