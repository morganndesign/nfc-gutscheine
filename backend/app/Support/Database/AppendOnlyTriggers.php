<?php

declare(strict_types=1);

namespace App\Support\Database;

use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Database triggers that reject UPDATE and DELETE on an append-only table, whatever code or person sends them.
 * Used by the migrations of the ledger, payments, audit log and security event stream.
 */
final class AppendOnlyTriggers
{
    public static function create(string $table): void
    {
        foreach (['UPDATE', 'DELETE'] as $operation) {
            $name = self::name($table, $operation);
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
    }

    public static function drop(string $table): void
    {
        foreach (['UPDATE', 'DELETE'] as $operation) {
            DB::unprepared('DROP TRIGGER IF EXISTS '.self::name($table, $operation));
        }
    }

    private static function name(string $table, string $operation): string
    {
        return $table.'_no_'.strtolower($operation);
    }
}
