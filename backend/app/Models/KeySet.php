<?php

declare(strict_types=1);

namespace App\Models;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;
use App\Enums\KeySetStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * A set of card root keys (one per manufacturer, rotated at least yearly). Only metadata: the version, which
 * names the keys in the {@see CryptoProvider}, and their key check values. Never key material.
 *
 * @property string $id
 * @property string $version
 * @property string $manufacturer
 * @property KeySetStatus $status
 * @property array<string, string> $key_check_values
 */
class KeySet extends Model
{
    use HasUuids;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'status' => KeySetStatus::class,
            'key_check_values' => 'array',
        ];
    }

    /** A root key of this set in the crypto provider, e.g. `ks-2026-01/k1`. */
    public function key(string $role): KeyReference
    {
        return KeyReference::of($this->version, $role);
    }
}
