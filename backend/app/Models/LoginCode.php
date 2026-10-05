<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One sign-in waiting for its e-mailed code (only the code's keyed hash is stored): the dashboard (`web`) or the
 * waiter app (`app`, bound to the phone that asked).
 *
 * @property string $id
 * @property string $user_id
 * @property string $client `web` or `app`
 * @property string|null $device_id The phone of an app sign-in (X-Device-Id)
 * @property string $code_hash
 * @property bool $remember
 * @property int $attempts
 * @property int $sends
 * @property Carbon $sent_at
 * @property Carbon $expires_at
 * @property Carbon|null $used_at
 * @property-read User $user
 */
class LoginCode extends Model
{
    use HasUuids;

    protected function casts(): array
    {
        return ['remember' => 'boolean', 'sent_at' => 'datetime', 'expires_at' => 'datetime', 'used_at' => 'datetime'];
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
