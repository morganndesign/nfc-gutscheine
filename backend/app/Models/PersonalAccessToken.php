<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\PersonalAccessToken as SanctumPersonalAccessToken;

/**
 * API tokens for POS / integration access and waiter app sign-ins (device-bound). Tokens are never deleted: revocation stamps
 * `revoked_at` and Sanctum's authentication callback rejects revoked tokens.
 *
 * @property string $id
 * @property string|null $restaurant_id
 * @property string|null $device_id Set for waiter app sign-ins: the token only works from this device
 * @property string|null $last_used_ip
 * @property Carbon|null $revoked_at
 * @property string|null $revoked_by
 * @property-read Restaurant|null $restaurant
 */
class PersonalAccessToken extends SanctumPersonalAccessToken
{
    use HasUuids;

    protected $fillable = ['name', 'token', 'abilities', 'expires_at', 'restaurant_id'];

    protected function casts(): array
    {
        return array_merge(parent::casts(), [
            'revoked_at' => 'datetime',
        ]);
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class)->withTrashed();
    }

    public function isRevoked(): bool
    {
        return $this->revoked_at !== null;
    }

    public function isUsable(): bool
    {
        return ! $this->isRevoked() && ($this->expires_at === null || $this->expires_at->isFuture());
    }
}
