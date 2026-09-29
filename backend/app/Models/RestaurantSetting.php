<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Voucher rules of one restaurant. All limits are in minor units and stay within the platform ceilings
 * (config giftcard.limits).
 *
 * @property string $id
 * @property string $restaurant_id
 * @property int|null $validity_months Null: vouchers do not expire (the default; Austrian law, architecture §5.2).
 * @property int $min_voucher_value
 * @property int $max_voucher_balance
 * @property int $max_debit_per_transaction
 * @property int $max_debit_per_voucher_per_day
 * @property int $max_redemptions_per_voucher_per_hour
 * @property bool $allow_reload
 * @property bool $allow_partial_redemption
 * @property bool $send_customer_emails
 * @property string $brand_color
 * @property string|null $receipt_footer
 */
class RestaurantSetting extends Model
{
    use HasUuids;

    protected $fillable = [
        'validity_months', 'min_voucher_value', 'max_voucher_balance', 'max_debit_per_transaction',
        'max_debit_per_voucher_per_day', 'max_redemptions_per_voucher_per_hour', 'allow_reload',
        'allow_partial_redemption', 'send_customer_emails', 'brand_color', 'receipt_footer',
    ];

    protected $attributes = [
        'validity_months' => null,
        'min_voucher_value' => 500,
        'max_voucher_balance' => 50000,
        'max_debit_per_transaction' => 25000,
        'max_debit_per_voucher_per_day' => 50000,
        'max_redemptions_per_voucher_per_hour' => 10,
        'allow_reload' => true,
        'allow_partial_redemption' => true,
        'send_customer_emails' => true,
        'brand_color' => '#0F172A',
    ];

    protected function casts(): array
    {
        return [
            'validity_months' => 'integer',
            'min_voucher_value' => 'integer',
            'max_voucher_balance' => 'integer',
            'max_debit_per_transaction' => 'integer',
            'max_debit_per_voucher_per_day' => 'integer',
            'max_redemptions_per_voucher_per_hour' => 'integer',
            'allow_reload' => 'boolean',
            'allow_partial_redemption' => 'boolean',
            'send_customer_emails' => 'boolean',
        ];
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }
}
