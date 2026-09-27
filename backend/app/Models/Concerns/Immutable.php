<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use App\Exceptions\Domain\ImmutableRecordException;
use Illuminate\Database\Eloquent\Model;

/**
 * Append-only ledger records: can be created, never deleted, and only the
 * attributes listed in $mutableAfterCreate may be changed afterwards.
 *
 * @mixin Model
 */
trait Immutable
{
    public static function bootImmutable(): void
    {
        static::updating(static function (Model $model): void {
            /** @var list<string> $allowed */
            $allowed = property_exists($model, 'mutableAfterCreate') ? $model->mutableAfterCreate : [];
            $forbidden = array_diff(array_keys($model->getDirty()), $allowed);

            if ($forbidden !== []) {
                throw new ImmutableRecordException(sprintf(
                    '%s records are immutable (attempted to change: %s).',
                    class_basename($model),
                    implode(', ', $forbidden),
                ));
            }
        });

        static::deleting(static function (Model $model): never {
            throw new ImmutableRecordException(sprintf('%s records can never be deleted.', class_basename($model)));
        });
    }
}
