<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\PaymentMethod;
use App\Models\Concerns\BelongsToRestaurant;
use App\Models\Concerns\HashChained;
use App\Models\Concerns\Immutable;
use App\Models\Contracts\HashChainedRecord;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * The money received for a sale or reload (decision 25). Append-only and hash-chained: a payment is a fact.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $voucher_id
 * @property PaymentMethod $method
 * @property int $amount
 * @property string $currency
 * @property string|null $reference
 * @property string|null $approved_by
 * @property string|null $reason
 * @property string|null $received_by
 * @property string|null $device_id
 * @property Carbon $created_at
 * @property-read Voucher $voucher
 * @property-read User|null $receiver
 */
class Payment extends Model implements HashChainedRecord
{
    use BelongsToRestaurant;
    use HashChained;
    use HasUuids;
    use Immutable;

    public const UPDATED_AT = null;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'method' => PaymentMethod::class,
            'amount' => 'integer',
            'chain_seq' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public static function chainName(): string
    {
        return 'payments';
    }

    public function chainAttributes(): array
    {
        return [
            'id', 'restaurant_id', 'voucher_id', 'method', 'amount', 'currency', 'reference', 'approved_by', 'reason',
            'received_by', 'device_id', 'created_at',
        ];
    }

    /** @return BelongsTo<Voucher, $this> */
    public function voucher(): BelongsTo
    {
        return $this->belongsTo(Voucher::class);
    }

    /** @return BelongsTo<User, $this> */
    public function receiver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'received_by')->withTrashed();
    }
}
