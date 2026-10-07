<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * A POS company that redeems vouchers in its own till app (decision 2026-10-07). It authenticates with one partner
 * key (`gcpp_…`, only its hash is stored) and reaches only the restaurants that connected it.
 *
 * @property string $id
 * @property string $name
 * @property string|null $contact_email
 * @property string $key_hash
 * @property string $key_prefix
 * @property string $status active | suspended
 * @property Carbon|null $last_used_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class Partner extends Model
{
    use HasUuids;

    public const KEY_PREFIX = 'gcpp_';

    protected $guarded = ['id'];

    protected $hidden = ['key_hash'];

    protected function casts(): array
    {
        return ['last_used_at' => 'datetime'];
    }

    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    public static function hashKey(string $key): string
    {
        return hash('sha256', $key);
    }

    /** @return HasMany<PartnerConnection, $this> */
    public function connections(): HasMany
    {
        return $this->hasMany(PartnerConnection::class)->withoutGlobalScopes();
    }
}
