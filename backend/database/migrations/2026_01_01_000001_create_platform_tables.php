<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('restaurants', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name', 160);
            $table->string('slug', 80)->unique();
            $table->string('legal_name', 200)->nullable();
            $table->string('vat_number', 40)->nullable();
            $table->string('email', 191)->nullable();
            $table->string('phone', 40)->nullable();
            $table->string('website', 191)->nullable();
            $table->string('address_line1', 191)->nullable();
            $table->string('address_line2', 191)->nullable();
            $table->string('postal_code', 20)->nullable();
            $table->string('city', 100)->nullable();
            $table->char('country', 2)->default('AT');
            $table->char('currency', 3)->default('EUR');
            $table->string('timezone', 64)->default('Europe/Vienna');
            $table->string('locale', 10)->default('de-AT');
            $table->string('status', 20)->default('active')->index();
            $table->string('plan', 40)->default('standard');
            $table->timestamp('suspended_at')->nullable();
            $table->string('suspension_reason', 500)->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('restaurant_settings', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('restaurant_id')->unique()->constrained()->restrictOnDelete();
            // No expiry unless the restaurant sets one; a set validity is at least 36 months (architecture §5.2).
            $table->unsignedSmallInteger('validity_months')->nullable();
            // Limits in minor units (architecture §6.3), within the platform ceilings of config/giftcard.php.
            $table->unsignedBigInteger('min_voucher_value')->default(500);
            $table->unsignedBigInteger('max_voucher_balance')->default(50000);
            $table->unsignedBigInteger('max_debit_per_transaction')->default(25000);
            $table->unsignedBigInteger('max_debit_per_voucher_per_day')->default(50000);
            $table->unsignedSmallInteger('max_redemptions_per_voucher_per_hour')->default(10);
            $table->boolean('allow_reload')->default(true);
            $table->boolean('allow_partial_redemption')->default(true);
            $table->boolean('send_customer_emails')->default(true);
            // A guest tapping their card with their own phone sees the balance (SUN-verified, architecture §10.3).
            $table->boolean('public_balance')->default(true);
            $table->string('brand_color', 7)->default('#0F172A');
            $table->string('receipt_footer', 500)->nullable();
            $table->timestamps();
        });

        Schema::create('system_settings', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('key', 120)->unique();
            $table->json('value')->nullable();
            $table->string('type', 20)->default('string');
            $table->string('description', 500)->nullable();
            $table->boolean('is_public')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('system_settings');
        Schema::dropIfExists('restaurant_settings');
        Schema::dropIfExists('restaurants');
    }
};
