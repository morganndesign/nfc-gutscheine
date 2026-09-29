<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\CardState;
use App\Models\Concerns\HashChained;
use App\Models\Concerns\Immutable;
use App\Models\Contracts\HashChainedRecord;
use App\Models\Scopes\RestaurantScope;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * One card state change (architecture §7.2): append-only and hash-chained per restaurant.
 *
 * @property string $id
 * @property string $card_id
 * @property string $batch_id
 * @property string|null $restaurant_id
 * @property CardState|null $from_state
 * @property CardState $to_state
 * @property string $reason
 * @property string|null $actor_id
 * @property string|null $device_id
 * @property string|null $request_id
 * @property string|null $ref_type
 * @property string|null $ref_id
 * @property Carbon $created_at
 */
class CardEvent extends Model implements HashChainedRecord
{
    use HashChained;
    use HasUuids;
    use Immutable;

    public const UPDATED_AT = null;

    protected $guarded = ['id'];

    protected $hidden = ['card_id'];

    protected static function booted(): void
    {
        static::addGlobalScope(new RestaurantScope);
    }

    protected function casts(): array
    {
        return [
            'from_state' => CardState::class,
            'to_state' => CardState::class,
            'created_at' => 'datetime',
            'chain_seq' => 'integer',
        ];
    }

    public static function chainName(): string
    {
        return 'card_events';
    }

    public function chainAttributes(): array
    {
        return [
            'id', 'card_id', 'batch_id', 'restaurant_id', 'from_state', 'to_state', 'reason', 'actor_id', 'device_id',
            'request_id', 'ref_type', 'ref_id', 'created_at',
        ];
    }
}
