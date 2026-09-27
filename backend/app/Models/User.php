<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\Permission as PermissionEnum;
use App\Enums\RoleSlug;
use App\Enums\UserStatus;
use App\Services\Users\UserService;
use Database\Factories\UserFactory;
use Illuminate\Auth\Passwords\CanResetPassword;
use Illuminate\Contracts\Auth\CanResetPassword as CanResetPasswordContract;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\HasApiTokens;

/**
 * Users are not tenant-scoped by global scope (authentication must resolve them before a tenant
 * exists); every query for restaurant staff goes through {@see UserService}
 * which constrains by restaurant explicitly.
 *
 * @property string $id
 * @property string|null $restaurant_id
 * @property string $role_id
 * @property string $name
 * @property string $email
 * @property string $password
 * @property UserStatus $status
 * @property string $locale
 * @property Carbon|null $last_login_at
 * @property string|null $last_login_ip
 * @property Carbon|null $password_changed_at
 * @property int $failed_login_attempts
 * @property Carbon|null $locked_until
 * @property Carbon $created_at
 * @property-read Role $role
 * @property-read Restaurant|null $restaurant
 */
class User extends Authenticatable implements CanResetPasswordContract
{
    use CanResetPassword;
    use HasApiTokens;

    /** @use HasFactory<UserFactory> */
    use HasFactory;

    use HasUuids;
    use Notifiable;
    use SoftDeletes;

    protected $fillable = ['name', 'email', 'password', 'locale'];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password_changed_at' => 'datetime',
            'locked_until' => 'datetime',
            'password' => 'hashed',
            'status' => UserStatus::class,
            'failed_login_attempts' => 'integer',
        ];
    }

    /** @return BelongsTo<Role, $this> */
    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    public function roleSlug(): RoleSlug
    {
        return $this->role->slug;
    }

    public function isPlatformAdmin(): bool
    {
        return $this->roleSlug() === RoleSlug::PlatformAdmin;
    }

    public function isActive(): bool
    {
        return $this->status === UserStatus::Active;
    }

    public function isLocked(): bool
    {
        return $this->locked_until !== null && $this->locked_until->isFuture();
    }

    public function hasPermission(PermissionEnum|string $permission): bool
    {
        $slug = $permission instanceof PermissionEnum ? $permission->value : $permission;

        if (! in_array($slug, $this->role->permissionSlugs(), true)) {
            return false;
        }

        // API tokens may be further restricted to a subset of abilities.
        $token = $this->currentAccessToken();

        return $token === null || $token->can($slug);
    }

    /** @return list<string> */
    public function effectivePermissions(): array
    {
        return array_values(array_filter(
            $this->role->permissionSlugs(),
            fn (string $slug): bool => $this->hasPermission($slug),
        ));
    }

    public function belongsToRestaurant(Restaurant|string|null $restaurant): bool
    {
        $id = $restaurant instanceof Restaurant ? $restaurant->getKey() : $restaurant;

        return $id !== null && $this->restaurant_id === $id;
    }

    public function canManageRole(Role $role): bool
    {
        return $this->roleSlug()->rank() > $role->slug->rank()
            || ($this->roleSlug() === RoleSlug::Owner && $role->slug === RoleSlug::Owner);
    }
}
