<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\Immutable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * A seal over the security events `from_seq`..`to_seq` (append-only). `seal_hash` chains each seal to the
 * previous one, so a changed, removed or later-inserted event inside a sealed range is detected.
 *
 * @property int $id
 * @property int $from_seq
 * @property int $to_seq
 * @property int $event_count
 * @property string $events_hash
 * @property string $prev_hash
 * @property string $seal_hash
 * @property Carbon $sealed_at
 */
class SecurityEventSeal extends Model
{
    use Immutable;

    public $timestamps = false;

    /** Microseconds are kept: they order events within a second and are part of the seal. */
    protected $dateFormat = 'Y-m-d H:i:s.u';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'from_seq' => 'integer',
            'to_seq' => 'integer',
            'event_count' => 'integer',
            'sealed_at' => 'immutable_datetime',
        ];
    }
}
