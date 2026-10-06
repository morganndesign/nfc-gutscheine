<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\OnlineOrderStatus;
use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * An order from a restaurant's shop. It becomes a voucher only when the provider's signed webhook confirms the
 * payment (never on the buyer's return to the shop).
 *
 * @property string $id
 * @property string $restaurant_id
 * @property OnlineOrderStatus $status
 * @property int $amount
 * @property string $currency
 * @property string $buyer_email
 * @property string|null $buyer_name
 * @property string|null $recipient_name
 * @property string|null $gift_message
 * @property bool $card_pickup
 * @property string $locale
 * @property string $status_token_hash
 * @property string $provider
 * @property string $account_id
 * @property string|null $checkout_id
 * @property string|null $payment_id
 * @property int $application_fee
 * @property string|null $voucher_id
 * @property string|null $ip_hash
 * @property Carbon $expires_at
 * @property Carbon|null $paid_at
 * @property Carbon|null $card_picked_up_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read Restaurant $restaurant
 * @property-read Voucher|null $voucher
 */
class OnlineOrder extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    protected $guarded = ['id'];

    protected $hidden = ['status_token_hash', 'ip_hash'];

    protected function casts(): array
    {
        return [
            'status' => OnlineOrderStatus::class,
            'amount' => 'integer',
            'card_pickup' => 'boolean',
            'application_fee' => 'integer',
            'expires_at' => 'datetime',
            'paid_at' => 'datetime',
            'card_picked_up_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Voucher, $this> */
    public function voucher(): BelongsTo
    {
        return $this->belongsTo(Voucher::class);
    }

    /** The card for this voucher waits to be picked up at the restaurant. */
    public function awaitsCardPickup(): bool
    {
        return $this->card_pickup && $this->card_picked_up_at === null && $this->status === OnlineOrderStatus::Paid;
    }

    /**
     * The gift card of an online voucher still waiting to be picked up: from when (null: no card waits).
     *
     * @return array{open: bool, from: string|null}|null
     */
    public static function pickupOf(Voucher $voucher): ?array
    {
        /** @var self|null $order */
        $order = self::query()->withoutGlobalScopes()->where('voucher_id', $voucher->getKey())->where('card_pickup', true)->first();
        if ($order === null) {
            return null;
        }

        return ['open' => $order->awaitsCardPickup(), 'from' => $order->cardPickupFrom()?->toIso8601String()];
    }

    /** When the card may be bound at the earliest (stolen-card purchases are disputed within hours). */
    public function cardPickupFrom(): ?Carbon
    {
        return $this->paid_at?->copy()->addHours((int) config('giftcard.online.card_pickup_after_hours', 24));
    }
}
