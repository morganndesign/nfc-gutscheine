<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use App\Exceptions\Domain\ImmutableRecordException;
use Illuminate\Database\Eloquent\Model;

/**
 * Append-only records: created once, never changed, never deleted. The database enforces the same rule with
 * triggers; this guard fails earlier, with a clear exception. Corrections are new records.
 *
 * @mixin Model
 */
trait Immutable
{
    public static function bootImmutable(): void
    {
        static::updating(static function (Model $model): never {
            throw new ImmutableRecordException(sprintf('%s records are append-only and can never be changed.', class_basename($model)));
        });

        static::deleting(static function (Model $model): never {
            throw new ImmutableRecordException(sprintf('%s records are append-only and can never be deleted.', class_basename($model)));
        });
    }
}
