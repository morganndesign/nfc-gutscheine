<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $restaurant_id
 * @property string $card_number_prefix
 * @property int $default_validity_months
 * @property int $min_card_value
 * @property int $max_card_value
 * @property int $max_card_balance
 * @property int|null $max_single_redemption
 * @property int $max_redemptions_per_card_per_hour
 * @property bool $allow_reload
 * @property bool $allow_partial_redemption
 * @property bool $public_balance_check
 * @property bool $enforce_nfc_uid_binding
 * @property bool $lock_nfc_tags_after_write
 * @property bool $send_customer_emails
 * @property string $brand_color
 * @property string|null $receipt_footer
 */
class RestaurantSetting extends Model
{
    use HasUuids;

    protected $fillable = [
        'card_number_prefix', 'default_validity_months', 'min_card_value', 'max_card_value',
        'max_card_balance', 'max_single_redemption', 'max_redemptions_per_card_per_hour',
        'allow_reload', 'allow_partial_redemption', 'public_balance_check',
        'enforce_nfc_uid_binding', 'lock_nfc_tags_after_write', 'send_customer_emails',
        'brand_color', 'receipt_footer',
    ];

    protected $attributes = [
        'card_number_prefix' => '',
        'default_validity_months' => 36,
        'min_card_value' => 500,
        'max_card_value' => 100000,
        'max_card_balance' => 200000,
        'max_redemptions_per_card_per_hour' => 10,
        'allow_reload' => true,
        'allow_partial_redemption' => true,
        'public_balance_check' => true,
        'enforce_nfc_uid_binding' => true,
        'lock_nfc_tags_after_write' => false,
        'send_customer_emails' => true,
        'brand_color' => '#0F172A',
    ];

    protected function casts(): array
    {
        return [
            'default_validity_months' => 'integer',
            'min_card_value' => 'integer',
            'max_card_value' => 'integer',
            'max_card_balance' => 'integer',
            'max_single_redemption' => 'integer',
            'max_redemptions_per_card_per_hour' => 'integer',
            'allow_reload' => 'boolean',
            'allow_partial_redemption' => 'boolean',
            'public_balance_check' => 'boolean',
            'enforce_nfc_uid_binding' => 'boolean',
            'lock_nfc_tags_after_write' => 'boolean',
            'send_customer_emails' => 'boolean',
        ];
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }
}
