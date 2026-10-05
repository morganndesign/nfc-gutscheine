<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\MediumStatus;
use App\Enums\VoucherKind;
use App\Enums\VoucherStatus;
use App\Models\Concerns\BelongsToRestaurant;
use App\Services\Vouchers\VoucherService;
use Database\Factories\VoucherFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * A voucher: the money. It owns balance, ledger, expiry, status, payments and the optional customer, and
 * nothing about how it is presented (that is a {@see Medium}).
 *
 * Money and state columns change only through {@see VoucherService}, atomically under a row lock and
 * together with the ledger entry.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string|null $customer_id
 * @property VoucherKind $kind
 * @property bool $is_loyalty Sold as loyalty (decision 2026-10-05); set at the sale only.
 * @property string $voucher_number Internal: staff and support only, never printed, never a credential.
 * @property VoucherStatus $status
 * @property string $currency
 * @property int $initial_value
 * @property int $balance
 * @property int $total_loaded
 * @property int $total_redeemed
 * @property Carbon|null $expires_at
 * @property Carbon|null $blocked_at
 * @property string|null $blocked_reason
 * @property Carbon|null $expired_at
 * @property string|null $issued_by
 * @property string|null $recipient_name
 * @property string|null $gift_message
 * @property string|null $notes
 * @property Carbon|null $last_used_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read Restaurant $restaurant
 * @property-read Customer|null $customer
 * @property-read User|null $issuer
 */
class Voucher extends Model
{
    use BelongsToRestaurant;

    /** @use HasFactory<VoucherFactory> */
    use HasFactory;

    use HasUuids;

    /** Money and state columns are deliberately not fillable: only the service layer changes them. */
    protected $fillable = ['customer_id', 'recipient_name', 'gift_message', 'notes'];

    protected function casts(): array
    {
        return [
            'kind' => VoucherKind::class,
            'is_loyalty' => 'boolean',
            'status' => VoucherStatus::class,
            'initial_value' => 'integer',
            'balance' => 'integer',
            'total_loaded' => 'integer',
            'total_redeemed' => 'integer',
            'expires_at' => 'datetime',
            'blocked_at' => 'datetime',
            'expired_at' => 'datetime',
            'last_used_at' => 'datetime',
        ];
    }

    public function isExpiredByDate(?Carbon $now = null): bool
    {
        return $this->expires_at !== null && $this->expires_at->lessThanOrEqualTo($now ?? Carbon::now());
    }

    public function isSpendable(): bool
    {
        return $this->status === VoucherStatus::Active && ! $this->isExpiredByDate() && $this->balance > 0;
    }

    /** @return BelongsTo<Customer, $this> */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    /** @return BelongsTo<User, $this> */
    public function issuer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'issued_by')->withTrashed();
    }

    /** @return HasMany<VoucherTransaction, $this> */
    public function transactions(): HasMany
    {
        return $this->hasMany(VoucherTransaction::class)->orderByDesc('created_at');
    }

    /** @return HasMany<Medium, $this> */
    public function media(): HasMany
    {
        return $this->hasMany(Medium::class);
    }

    /** @return HasMany<Medium, $this> */
    public function activeMedia(): HasMany
    {
        return $this->hasMany(Medium::class)->where('status', MediumStatus::Active->value);
    }

    /**
     * A loyalty voucher (decision 2026-10-05): sold as loyalty (`complimentary`), set once at the sale and never
     * later. Only such a voucher takes further loyalty value; paid top-ups are allowed on it too.
     */
    public function isLoyalty(): bool
    {
        return $this->is_loyalty;
    }

    /**
     * @param  Builder<Voucher>  $query
     * @return Builder<Voucher>
     */
    public function scopeLoyalty(Builder $query, bool $loyalty = true): Builder
    {
        return $query->where('is_loyalty', $loyalty);
    }

    /** @return HasMany<Payment, $this> */
    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    /**
     * Staff search: the internal voucher number, the recipient, notes and the customer.
     *
     * @param  Builder<Voucher>  $query
     * @return Builder<Voucher>
     */
    public function scopeSearch(Builder $query, ?string $term): Builder
    {
        if ($term === null || trim($term) === '') {
            return $query;
        }

        $term = trim($term);
        $digits = preg_replace('/\D+/', '', $term) ?? '';
        $like = '%'.addcslashes($term, '%_\\').'%';

        return $query->where(static function (Builder $q) use ($term, $digits, $like): void {
            if ($digits !== '') {
                $q->orWhere('voucher_number', 'like', '%'.$digits.'%');
            }
            $q->orWhere('recipient_name', 'like', $like)
                ->orWhere('notes', 'like', $like)
                ->orWhereHas('customer', static function (Builder $c) use ($term): void {
                    /** @var Builder<Customer> $c */
                    $c->search($term);
                });
        });
    }

    /**
     * Vouchers that still carry a liability towards guests (expired and blocked vouchers keep their balance).
     *
     * @param  Builder<Voucher>  $query
     * @return Builder<Voucher>
     */
    public function scopeOutstanding(Builder $query): Builder
    {
        return $query->where('balance', '>', 0);
    }
}
