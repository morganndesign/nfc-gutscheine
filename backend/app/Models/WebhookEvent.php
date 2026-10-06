<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * A payment provider event, recorded once: the provider retries until it gets an answer, and a retry of an event
 * that was processed is answered without doing it again.
 *
 * @property string $id
 * @property string $provider
 * @property string $event_id
 * @property string $type
 * @property string|null $account_id
 * @property Carbon|null $processed_at
 */
class WebhookEvent extends Model
{
    use HasUuids;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return ['processed_at' => 'datetime'];
    }
}
