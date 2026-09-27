<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\RoleSlug;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Cache;

/**
 * @property string $id
 * @property RoleSlug $slug
 * @property string $name
 * @property string|null $description
 * @property string $scope
 * @property int $rank
 * @property bool $is_system
 */
class Role extends Model
{
    use HasUuids;

    protected $fillable = ['slug', 'name', 'description', 'scope', 'rank', 'is_system'];

    protected function casts(): array
    {
        return [
            'slug' => RoleSlug::class,
            'rank' => 'integer',
            'is_system' => 'boolean',
        ];
    }

    public static function findBySlug(RoleSlug $slug): self
    {
        return static::query()->where('slug', $slug->value)->firstOrFail();
    }

    /** @return BelongsToMany<Permission, $this> */
    public function permissions(): BelongsToMany
    {
        return $this->belongsToMany(Permission::class);
    }

    /** @return HasMany<User, $this> */
    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    /**
     * Permission slugs granted to this role (cached; flushed whenever permissions are synced).
     *
     * @return list<string>
     */
    public function permissionSlugs(): array
    {
        /** @var list<string> */
        return Cache::rememberForever(
            self::permissionCacheKey($this->getKey()),
            fn (): array => $this->permissions()->pluck('slug')->all(),
        );
    }

    /** @param list<string> $permissionIds */
    public function syncPermissions(array $permissionIds): void
    {
        $this->permissions()->sync($permissionIds);
        Cache::forget(self::permissionCacheKey($this->getKey()));
    }

    public static function permissionCacheKey(string $roleId): string
    {
        return "roles:{$roleId}:permissions";
    }
}
