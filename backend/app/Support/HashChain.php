<?php

declare(strict_types=1);

namespace App\Support;

use App\Models\Concerns\HashChained;
use App\Models\Contracts\HashChainedRecord;
use BackedEnum;
use DateTimeInterface;
use Illuminate\Database\ConnectionInterface;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use LogicException;

/**
 * Hash chains over the append-only tables. See {@see HashChained} for the construction.
 */
final class HashChain
{
    public const GENESIS = '0000000000000000000000000000000000000000000000000000000000000000';

    public const PLATFORM_SCOPE = 'platform';

    /**
     * Assigns chain position and hashes to a row that is about to be inserted. Must run inside the insert's
     * transaction (HashChained::performInsert).
     */
    public function link(Model&HashChainedRecord $model): void
    {
        $connection = $model->getConnection();
        if ($connection->transactionLevel() === 0) {
            throw new LogicException('Hash-chained rows can only be inserted inside a transaction.');
        }

        $createdAt = $model->getCreatedAtColumn();
        if ($model->usesTimestamps() && $createdAt !== null && $model->getAttribute($createdAt) === null) {
            $model->setCreatedAt($model->freshTimestamp());
        }

        $chain = $model::chainName();
        $scope = self::scopeOf($model->getAttribute('restaurant_id'));

        // Lock the head first. Only a chain's very first entry creates it: INSERT IGNORE on an existing row takes a
        // shared lock, and two writers upgrading shared to exclusive deadlock each other (found by the MySQL stress test).
        $head = $this->lockHead($connection, $chain, $scope);
        if ($head === null) {
            $connection->table('chain_heads')->insertOrIgnore([
                'chain' => $chain,
                'scope' => $scope,
                'seq' => 0,
                'head_hash' => self::GENESIS,
                'updated_at' => Carbon::now(),
            ]);
            $head = $this->lockHead($connection, $chain, $scope);
        }

        if ($head === null) {
            throw new LogicException("Chain head {$chain}/{$scope} is missing.");
        }

        $seq = $head['seq'] + 1;
        $prev = $head['head_hash'];

        $model->setAttribute('chain_scope', $scope);
        $model->setAttribute('chain_seq', $seq);
        $model->setAttribute('prev_hash', $prev);
        $model->setAttribute('entry_hash', self::entryHash($model, $chain, $scope, $seq, $prev));

        $connection->table('chain_heads')
            ->where('chain', $chain)
            ->where('scope', $scope)
            ->update(['seq' => $seq, 'head_hash' => $model->getAttribute('entry_hash'), 'updated_at' => Carbon::now()]);
    }

    /** @return array{seq: int, head_hash: string}|null */
    private function lockHead(ConnectionInterface $connection, string $chain, string $scope): ?array
    {
        $row = $connection->table('chain_heads')
            ->where('chain', $chain)
            ->where('scope', $scope)
            ->lockForUpdate()
            ->first(['seq', 'head_hash']);

        return $row === null ? null : ['seq' => (int) $row->seq, 'head_hash' => (string) $row->head_hash];
    }

    public static function entryHash(Model&HashChainedRecord $model, string $chain, string $scope, int $seq, string $prev): string
    {
        $payload = [];
        foreach ($model->chainAttributes() as $attribute) {
            $payload[$attribute] = self::normalize($model->getAttribute($attribute));
        }

        return hash('sha256', $prev.self::canonicalJson([$chain, $scope, $seq, $payload]));
    }

    public static function scopeOf(mixed $restaurantId): string
    {
        return is_string($restaurantId) && $restaurantId !== '' ? $restaurantId : self::PLATFORM_SCOPE;
    }

    /**
     * The same value before insert and after a database round trip: datetimes in UTC to the second, enums by
     * value, arrays with sorted keys (MySQL's JSON type reorders keys).
     */
    private static function normalize(mixed $value): mixed
    {
        return match (true) {
            $value instanceof DateTimeInterface => Carbon::instance($value)->utc()->format('Y-m-d H:i:s'),
            $value instanceof BackedEnum => $value->value,
            is_array($value) => self::sortKeys($value),
            default => $value,
        };
    }

    /**
     * @param  array<mixed>  $value
     * @return array<mixed>
     */
    private static function sortKeys(array $value): array
    {
        $normalized = array_map(self::normalize(...), $value);
        if (! array_is_list($normalized)) {
            ksort($normalized, SORT_STRING);
        }

        return $normalized;
    }

    private static function canonicalJson(mixed $value): string
    {
        return json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR);
    }
}
