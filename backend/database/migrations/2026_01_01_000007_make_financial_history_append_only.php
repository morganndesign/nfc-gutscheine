<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Financial history and the audit trail are append-only (architecture §13.1, decision "no historical financial
 * event may ever be modified or deleted"): the database itself rejects UPDATE and DELETE, whatever code or
 * person sends them. Corrections are new rows (a reversal, a new status event).
 *
 * In production the application's database user additionally has no UPDATE/DELETE grant on these tables
 * (Phase 9, three database users); the triggers make the rule hold in every environment, tests included.
 */
return new class extends Migration
{
    /** @var list<string> */
    public const TABLES = ['voucher_transactions', 'payments', 'audit_logs'];

    public function up(): void
    {
        foreach (self::TABLES as $table) {
            foreach (['UPDATE', 'DELETE'] as $operation) {
                $this->createTrigger($table, $operation);
            }
        }
    }

    public function down(): void
    {
        foreach (self::TABLES as $table) {
            foreach (['UPDATE', 'DELETE'] as $operation) {
                DB::unprepared('DROP TRIGGER IF EXISTS '.$this->name($table, $operation));
            }
        }
    }

    private function createTrigger(string $table, string $operation): void
    {
        $name = $this->name($table, $operation);
        $message = "{$table} is append-only: {$operation} is not allowed";

        match (DB::connection()->getDriverName()) {
            'mysql', 'mariadb' => DB::unprepared(
                "CREATE TRIGGER {$name} BEFORE {$operation} ON {$table} FOR EACH ROW "
                ."SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '{$message}'"
            ),
            'sqlite' => DB::unprepared(
                "CREATE TRIGGER {$name} BEFORE {$operation} ON {$table} BEGIN SELECT RAISE(ABORT, '{$message}'); END"
            ),
            default => throw new RuntimeException('Append-only triggers are not implemented for this database driver.'),
        };
    }

    private function name(string $table, string $operation): string
    {
        return $table.'_no_'.strtolower($operation);
    }
};
