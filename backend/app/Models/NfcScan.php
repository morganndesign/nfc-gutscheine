<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\ScanMethod;
use App\Enums\ScanResult;
use App\Models\Concerns\Immutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Every card lookup (NFC tap, QR scan, manual entry) is recorded for fraud analysis,
 * brute-force detection and clone detection. Not tenant-scoped via global scope because
 * foreign-restaurant attempts must also be recorded.
 *
 * @property string $id
 * @property string|null $restaurant_id
 * @property string|null $gift_card_id
 * @property string|null $user_id
 * @property string|null $device_id
 * @property ScanMethod $method
 * @property ScanResult $result
 * @property string|null $nfc_uid
 * @property int|null $read_counter
 * @property string|null $ip_address
 * @property string|null $user_agent
 * @property Carbon $created_at
 */
class NfcScan extends Model
{
    use HasUuids;
    use Immutable;

    public const UPDATED_AT = null;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'method' => ScanMethod::class,
            'result' => ScanResult::class,
            'read_counter' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<GiftCard, $this> */
    public function giftCard(): BelongsTo
    {
        return $this->belongsTo(GiftCard::class)->withoutGlobalScopes();
    }
}
