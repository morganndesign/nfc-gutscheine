<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Collection;

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

    public const KEY_CARD_REPLACED = 'card_replaced';

    public const KEY_VOUCHER_REFUNDED = 'voucher_refunded';

    /**
     * Guest e-mails are receipts (ADR-003): the purchase or reload amount, the restaurant, the date and how it
     * was paid. They never contain anything that proves or spends the voucher: no QR payload, no voucher number,
     * no link to the voucher, no token or code. The balance lives on the server and is not repeated in e-mails.
     *
     * @var array<string, list<string>>
     */
    public const PLACEHOLDERS = [
        self::KEY_VOUCHER_ISSUED => ['restaurant_name', 'customer_name', 'amount', 'date', 'payment_method', 'validity'],
        self::KEY_VOUCHER_RELOADED => ['restaurant_name', 'customer_name', 'amount', 'date', 'payment_method'],
        self::KEY_VOUCHER_EXPIRING => ['restaurant_name', 'customer_name', 'expires_at'],
        self::KEY_CARD_REPLACED => ['restaurant_name', 'customer_name', 'date'],
        self::KEY_VOUCHER_REFUNDED => ['restaurant_name', 'customer_name', 'amount', 'date', 'payment_method'],
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

    /** The template language guests of a restaurant with [locale] get (Bosnian, Croatian and Serbian share BHS). */
    public static function languageOf(string $locale): string
    {
        $language = strtolower(substr($locale, 0, 2));

        return in_array($language, ['hr', 'sr'], true) ? 'bs' : $language;
    }

    /**
     * The template a restaurant's guests get for [key]: the guest language before English, the restaurant's own
     * version before the system default. Null when that template is switched off — then nothing is sent.
     */
    public static function resolve(?string $restaurantId, string $key, string $locale, string $channel = 'mail'): ?self
    {
        $template = self::effective($restaurantId, $locale, $channel)->get($key);

        return $template !== null && $template->is_active ? $template : null;
    }

    /**
     * Per key, the one template that applies to a restaurant with [locale] (switched off ones included).
     *
     * @return Collection<string, self>
     */
    public static function effective(?string $restaurantId, string $locale, string $channel = 'mail'): Collection
    {
        $language = self::languageOf($locale);

        return self::query()
            ->where('channel', $channel)
            ->whereIn('locale', array_unique([$locale, $language, 'en']))
            ->where(static function (Builder $q) use ($restaurantId): void {
                $q->whereNull('restaurant_id');
                if ($restaurantId !== null) {
                    $q->orWhere('restaurant_id', $restaurantId);
                }
            })
            ->get()
            ->sortBy(static fn (self $t): string => ($t->locale === $locale ? '0' : ($t->locale === $language ? '1' : '2'))
                .($t->restaurant_id === null ? '1' : '0'))
            ->unique('key')
            ->toBase()
            ->mapWithKeys(static fn (self $t): array => [$t->key => $t]);
    }
}
