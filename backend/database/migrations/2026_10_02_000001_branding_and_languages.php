<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The printed voucher's design (template, format, colours, texts, logo), the user's language (German by default,
 * Austria first) and no more "plans": the platform has none.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('restaurants', function (Blueprint $table): void {
            $table->dropColumn('plan');
        });

        Schema::table('restaurant_settings', function (Blueprint $table): void {
            $table->string('voucher_template', 20)->default('classic');
            $table->string('voucher_format', 4)->default('a5');
            $table->string('accent_color', 7)->default('#C9A86A');
            $table->string('voucher_headline', 60)->nullable();
            $table->string('voucher_message', 240)->nullable();
            // SHA-256 of the logo: the cache key clients use (null: no logo).
            $table->string('logo_version', 64)->nullable();
        });

        // In the database, not on disk: the logo is part of every backup and restore.
        Schema::create('restaurant_logos', function (Blueprint $table): void {
            $table->foreignUuid('restaurant_id')->primary()->constrained()->cascadeOnDelete();
            $table->string('mime', 20);
            $table->unsignedSmallInteger('width');
            $table->unsignedSmallInteger('height');
            $table->longText('data');
            $table->timestamps();
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->string('locale', 10)->default('de')->change();
        });
        // Nobody could choose a language before: everyone starts in German.
        DB::table('users')->where('locale', 'en')->update(['locale' => 'de']);

        DB::table('system_settings')->where('key', 'platform.default_plan')->delete();
    }

    public function down(): void
    {
        Schema::dropIfExists('restaurant_logos');
        Schema::table('restaurant_settings', function (Blueprint $table): void {
            $table->dropColumn(['voucher_template', 'voucher_format', 'accent_color', 'voucher_headline', 'voucher_message', 'logo_version']);
        });
        Schema::table('restaurants', function (Blueprint $table): void {
            $table->string('plan', 40)->default('standard');
        });
        Schema::table('users', function (Blueprint $table): void {
            $table->string('locale', 10)->default('en')->change();
        });
    }
};
