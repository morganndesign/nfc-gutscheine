<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

/**
 * Platform-wide key/value configuration managed by platform administrators.
 *
 * @property string $id
 * @property string $key
 * @property mixed $value
 * @property string $type
 * @property string|null $description
 * @property bool $is_public
 */
class SystemSetting extends Model
{
    use HasUuids;

    private const CACHE_KEY = 'system_settings:all';

    protected $fillable = ['key', 'value', 'type', 'description', 'is_public'];

    protected function casts(): array
    {
        return [
            'value' => 'json',
            'is_public' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::saved(static fn () => Cache::forget(self::CACHE_KEY));
    }

    public static function get(string $key, mixed $default = null): mixed
    {
        /** @var array<string, mixed> $all */
        $all = Cache::rememberForever(
            self::CACHE_KEY,
            static fn (): array => static::query()->pluck('value', 'key')->all(),
        );

        return array_key_exists($key, $all) ? $all[$key] : $default;
    }
}
