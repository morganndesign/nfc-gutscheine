<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The database-uuids failed-job provider lists and retries failed jobs ordered by an auto-increment `id`
 * (`queue:failed`, `queue:retry all`); without it both commands failed with "Unknown column 'id'". The uuid stays the
 * job's public key.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Rebuilt and copied (SQLite cannot add a primary key column); existing failed jobs are kept, oldest first.
        Schema::create('failed_jobs_next', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->text('connection');
            $table->text('queue');
            $table->longText('payload');
            $table->longText('exception');
            $table->timestamp('failed_at')->useCurrent();
        });
        DB::statement('INSERT INTO failed_jobs_next (uuid, connection, queue, payload, exception, failed_at) '
            .'SELECT uuid, connection, queue, payload, exception, failed_at FROM failed_jobs ORDER BY failed_at');
        Schema::drop('failed_jobs');
        Schema::rename('failed_jobs_next', 'failed_jobs');
    }

    public function down(): void
    {
        Schema::table('failed_jobs', function (Blueprint $table): void {
            $table->dropColumn('id');
        });
    }
};
