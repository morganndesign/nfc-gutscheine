<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * @property string $id
 * @property string|null $restaurant_id
 * @property string|null $gift_card_id
 * @property string $template_key
 * @property string $channel
 * @property string $recipient
 * @property string $status
 * @property string|null $error
 * @property Carbon|null $sent_at
 */
class NotificationLog extends Model
{
    use HasUuids;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return ['sent_at' => 'datetime'];
    }
}
