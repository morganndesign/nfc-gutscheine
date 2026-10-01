<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A restaurant's logo for the printed voucher and the waiter app's card: a re-encoded PNG (never the uploaded bytes),
 * base64 in the database so backups and restores carry it.
 *
 * @property string $restaurant_id
 * @property string $mime
 * @property int $width
 * @property int $height
 * @property string $data base64
 */
class RestaurantLogo extends Model
{
    protected $primaryKey = 'restaurant_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['restaurant_id', 'mime', 'width', 'height', 'data'];

    protected function casts(): array
    {
        return ['width' => 'integer', 'height' => 'integer'];
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }
}
