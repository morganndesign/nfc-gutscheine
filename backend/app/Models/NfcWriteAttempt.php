<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\NfcTagType;
use App\Enums\NfcWriteMethod;
use App\Enums\NfcWriteResult;
use App\Enums\NfcWriteStage;
use App\Models\Concerns\BelongsToRestaurant;
use App\Services\GiftCards\NfcProgrammingService;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One attempt to program a physical NFC tag for a card, from the first read to the final result.
 * Written by {@see NfcProgrammingService} only.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $gift_card_id
 * @property string|null $user_id
 * @property string|null $device_id
 * @property string $attempt_id
 * @property NfcWriteMethod $method
 * @property NfcWriteStage $stage
 * @property NfcWriteResult $result
 * @property string|null $error_code
 * @property string|null $error_message
 * @property string|null $uid
 * @property NfcTagType|null $tag_type
 * @property string|null $previous_url
 * @property string|null $read_back_url
 * @property string|null $conflict_card_id
 * @property bool $locked
 * @property int|null $detect_ms
 * @property int|null $write_ms
 * @property int|null $verify_ms
 * @property int|null $total_ms
 * @property string|null $user_agent
 * @property Carbon|null $completed_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read GiftCard $giftCard
 * @property-read User|null $user
 */
class NfcWriteAttempt extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'method' => NfcWriteMethod::class,
            'stage' => NfcWriteStage::class,
            'result' => NfcWriteResult::class,
            'tag_type' => NfcTagType::class,
            'locked' => 'boolean',
            'detect_ms' => 'integer',
            'write_ms' => 'integer',
            'verify_ms' => 'integer',
            'total_ms' => 'integer',
            'completed_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<GiftCard, $this> */
    public function giftCard(): BelongsTo
    {
        return $this->belongsTo(GiftCard::class);
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class)->withTrashed();
    }
}
