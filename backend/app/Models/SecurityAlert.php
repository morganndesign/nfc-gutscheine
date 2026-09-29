<?php

declare(strict_types=1);

namespace App\Models;

use App\Services\Security\SecurityMonitor;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * An alert raised by a fraud rule over the security event stream ({@see SecurityMonitor}).
 * Repeats of the same rule and subject within the dedup window only count up `occurrences`.
 *
 * @property string $id
 * @property string $rule
 * @property string $severity warning, high or critical
 * @property string|null $restaurant_id
 * @property string|null $subject
 * @property int $occurrences
 * @property int $first_event_seq
 * @property int $last_event_seq
 * @property Carbon $first_seen_at
 * @property Carbon $last_seen_at
 * @property string $status open or acknowledged
 * @property string|null $acknowledged_by
 * @property Carbon|null $acknowledged_at
 * @property string|null $note
 */
class SecurityAlert extends Model
{
    use HasUlids;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'occurrences' => 'integer',
            'first_event_seq' => 'integer',
            'last_event_seq' => 'integer',
            'first_seen_at' => 'datetime',
            'last_seen_at' => 'datetime',
            'acknowledged_at' => 'datetime',
        ];
    }
}
