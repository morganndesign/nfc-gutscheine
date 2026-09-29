<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Restaurant-specific templates override system defaults (restaurant_id = null).
 * Bodies use {{ placeholder }} syntax and are rendered with escaping by TemplateRenderer.
 *
 * @property string $id
 * @property string|null $restaurant_id
 * @property string $key
 * @property string $channel
 * @property string $locale
 * @property string $subject
 * @property string $body
 * @property bool $is_active
 */
class NotificationTemplate extends Model
{
    use HasUuids;

    public const KEY_VOUCHER_ISSUED = 'voucher_issued';

    public const KEY_VOUCHER_RELOADED = 'voucher_reloaded';

    public const KEY_VOUCHER_EXPIRING = 'voucher_expiring';

    /**
     * Guest e-mails never contain a balance, an amount, the voucher number or a link that shows the voucher
     * (architecture §6.4, decision 24): whoever reads a forwarded e-mail learns nothing they could use.
     *
     * @var array<string, list<string>>
     */
    public const PLACEHOLDERS = [
        self::KEY_VOUCHER_ISSUED => ['restaurant_name', 'customer_name', 'validity'],
        self::KEY_VOUCHER_RELOADED => ['restaurant_name', 'customer_name'],
        self::KEY_VOUCHER_EXPIRING => ['restaurant_name', 'customer_name', 'expires_at'],
    ];

    protected $fillable = ['restaurant_id', 'key', 'channel', 'locale', 'subject', 'body', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    public static function resolve(?string $restaurantId, string $key, string $locale, string $channel = 'mail'): ?self
    {
        $language = substr($locale, 0, 2);

        /** @var self|null */
        return static::query()
            ->where('key', $key)
            ->where('channel', $channel)
            ->where('is_active', true)
            ->whereIn('locale', array_unique([$locale, $language, 'en']))
            ->where(static function (Builder $q) use ($restaurantId): void {
                $q->whereNull('restaurant_id');
                if ($restaurantId !== null) {
                    $q->orWhere('restaurant_id', $restaurantId);
                }
            })
            ->get()
            ->sortBy(static fn (self $t): string => ($t->restaurant_id === null ? '1' : '0')
                .($t->locale === $locale ? '0' : ($t->locale === $language ? '1' : '2')))
            ->first();
    }
}
