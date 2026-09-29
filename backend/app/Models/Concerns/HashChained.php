<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use App\Models\Contracts\HashChainedRecord;
use App\Support\HashChain;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use LogicException;

/**
 * Links every new row into a per-restaurant hash chain (architecture §13.1, "tamper-evident audit"):
 *
 *   entry_hash = SHA-256(prev_hash ‖ canonical JSON of [chain, scope, seq, chained attributes])
 *
 * A changed, deleted or inserted row breaks the chain, which `giftcard:verify-chains` detects. The head of each
 * chain is locked while a row is appended, so concurrent writers get consecutive sequence numbers.
 *
 * Lock order (deadlock avoidance): payments → voucher_transactions → audit_logs. Code that writes several of
 * these in one transaction writes them in this order.
 *
 * The using model implements {@see HashChainedRecord}; `restaurant_id` decides the chain scope and must be set
 * before the row is saved. List this trait after BelongsToRestaurant so the tenant stamp runs first.
 *
 * @mixin Model
 */
trait HashChained
{
    public static function bootHashChained(): void
    {
        static::creating(static function (Model $model): void {
            if (! $model instanceof HashChainedRecord) {
                throw new LogicException(class_basename($model).' uses HashChained but does not implement HashChainedRecord.');
            }

            app(HashChain::class)->link($model);
        });
    }

    /** Appending to the chain and inserting the row are one atomic step. */
    protected function performInsert(Builder $query): bool
    {
        return $this->getConnection()->transaction(fn (): bool => parent::performInsert($query));
    }
}
