<?php

declare(strict_types=1);

use App\Support\Database\AppendOnlyTriggers;
use Illuminate\Database\Migrations\Migration;

/**
 * Financial history and the audit trail are append-only (architecture §13.1, decision "no historical financial
 * event may ever be modified or deleted"): the database itself rejects UPDATE and DELETE, whatever code or
 * person sends them. Corrections are new rows (a reversal, a new status event).
 *
 * The triggers make the rule hold in every environment, tests included. Separate database users without
 * UPDATE/DELETE grants on these tables follow in Phase 9.
 */
return new class extends Migration
{
    /** @var list<string> */
    public const TABLES = ['voucher_transactions', 'payments', 'audit_logs'];

    public function up(): void
    {
        foreach (self::TABLES as $table) {
            AppendOnlyTriggers::create($table);
        }
    }

    public function down(): void
    {
        foreach (self::TABLES as $table) {
            AppendOnlyTriggers::drop($table);
        }
    }
};
