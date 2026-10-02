<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The batch lifecycle without the two-person acceptance and the intermediate steps: in_production → accepted
 * (one release) → shipped → in_service / on_hold. Batches in a removed status move to the status that now covers it;
 * their cards keep their states (a delivered batch keeps delivered cards, which the receipt still accepts).
 */
return new class extends Migration
{
    /** Removed status => the status that replaces it. */
    public const MAP = [
        'ordered' => 'in_production',
        'personalized' => 'in_production',
        'qa_testing' => 'in_production',
        'assigned' => 'accepted',
        'delivered' => 'shipped',
    ];

    /** SQLite rebuilds the table to drop the column, which needs foreign key checks off: not possible in a transaction. */
    public $withinTransaction = false;

    public function up(): void
    {
        $this->mapStatuses();
        Schema::table('card_batches', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('accepted_second_by');
        });
    }

    public function mapStatuses(): void
    {
        foreach (self::MAP as $old => $new) {
            DB::table('card_batches')->where('status', $old)->update(['status' => $new]);
        }
    }

    public function down(): void
    {
        // The old statuses cannot be told apart again; only the column comes back.
        Schema::table('card_batches', function (Blueprint $table): void {
            $table->foreignUuid('accepted_second_by')->nullable()->constrained('users')->restrictOnDelete();
        });
    }
};
