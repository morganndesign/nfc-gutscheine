<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\MassPrunable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * A one-time code an owner gives to a POS company to connect its till system (24 hours, single use; only the hash
 * is stored). Pruned a week after it expired (used or not; the audit log keeps the history).
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $code_hash
 * @property string|null $created_by
 * @property Carbon $expires_at
 * @property Carbon|null $used_at
 * @property string|null $used_by_partner_id
 * @property Carbon|null $created_at
 */
class PartnerLinkCode extends Model
{
    use BelongsToRestaurant;
    use HasUuids;
    use MassPrunable;

    public const KEEP_DAYS = 7;

    protected $guarded = ['id'];

    /** @return Builder<static> */
    public function prunable(): Builder
    {
        return static::query()->withoutGlobalScopes()->where('expires_at', '<', Carbon::now()->subDays(self::KEEP_DAYS));
    }

    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'used_at' => 'datetime'];
    }
}
