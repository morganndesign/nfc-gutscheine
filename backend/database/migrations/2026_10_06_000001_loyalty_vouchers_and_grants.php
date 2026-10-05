<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Loyalty (decision 2026-10-05): a voucher is a loyalty voucher from its sale on (sold as loyalty), never later;
 * loyalty value only goes onto such a voucher. The owner allows single managers to give loyalty.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vouchers', function (Blueprint $table): void {
            $table->boolean('is_loyalty')->default(false)->after('kind');
        });
        Schema::table('users', function (Blueprint $table): void {
            $table->boolean('can_give_loyalty')->default(false)->after('status');
        });

        // Vouchers sold as loyalty so far. A paid voucher that got a loyalty top-up stays a paid voucher.
        DB::table('vouchers')->whereIn('id', DB::table('voucher_transactions')
            ->join('payments', 'payments.id', '=', 'voucher_transactions.payment_id')
            ->where('voucher_transactions.type', 'issue')
            ->where('payments.method', 'complimentary')
            ->select('voucher_transactions.voucher_id'))
            ->update(['is_loyalty' => true]);
    }

    public function down(): void
    {
        Schema::table('vouchers', function (Blueprint $table): void {
            $table->dropColumn('is_loyalty');
        });
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('can_give_loyalty');
        });
    }
};
