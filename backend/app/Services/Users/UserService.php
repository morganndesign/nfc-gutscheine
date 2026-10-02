<?php

declare(strict_types=1);

namespace App\Services\Users;

use App\Enums\RoleSlug;
use App\Enums\SecurityEventType;
use App\Enums\UserStatus;
use App\Exceptions\Domain\LastOwnerException;
use App\Exceptions\Domain\RoleAssignmentException;
use App\Jobs\SendPasswordResetLink;
use App\Models\Restaurant;
use App\Models\Role;
use App\Models\User;
use App\Notifications\SignInEmailChanged;
use App\Services\Audit\AuditLogger;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;

/**
 * Staff management within a restaurant. Users are never deleted: they are deactivated,
 * which also revokes their API tokens and terminates their sessions.
 */
final class UserService
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly InvitationService $invitations,
        private readonly SecurityEventRecorder $events,
    ) {}

    /**
     * @param  array{name: string, email: string, role: string, password?: string|null, locale?: string|null}  $data
     */
    public function create(Actor $actor, Restaurant $restaurant, array $data, bool $sendInvite = true): User
    {
        $role = Role::findBySlug(RoleSlug::from($data['role']));
        $this->assertAssignable($actor, $role);

        return DB::transaction(function () use ($actor, $restaurant, $data, $role, $sendInvite): User {
            $user = new User;
            $user->fill([
                'name' => $data['name'],
                'email' => Str::lower($data['email']),
                'password' => $data['password'] ?? Str::password(40),
                'locale' => $data['locale'] ?? 'de',
            ]);
            $user->forceFill([
                'restaurant_id' => $restaurant->getKey(),
                'role_id' => $role->getKey(),
                'status' => UserStatus::Active,
                'password_changed_at' => isset($data['password']) ? Carbon::now() : null,
            ])->save();

            $this->audit->log('user.created', $actor, $user, null, [
                'name' => $user->name,
                'email' => $user->email,
                'role' => $role->slug,
            ], restaurantId: $restaurant->getKey());
            $this->events->record(SecurityEventType::StaffCreate, $actor, subject: $user, data: ['role' => $role->slug], restaurantId: $restaurant->getKey());

            if ($sendInvite && ! isset($data['password'])) {
                $inviter = $actor->user?->name;
                DB::afterCommit(fn () => $this->sendInvitation($user, $restaurant, $inviter));
            }

            return $user;
        });
    }

    /**
     * @param  array{name?: string, email?: string, role?: string, locale?: string}  $data
     */
    public function update(Actor $actor, User $user, array $data): User
    {
        $this->assertManageable($actor, $user);

        return DB::transaction(function () use ($actor, $user, $data): User {
            $old = $user->only(['name', 'email', 'locale', 'role_id']);
            $previousRole = $user->roleSlug();

            if (isset($data['role'])) {
                $role = Role::findBySlug(RoleSlug::from($data['role']));
                $this->assertAssignable($actor, $role);
                if ($user->is($actor->user) && $role->getKey() !== $user->role_id) {
                    throw new RoleAssignmentException('You cannot change your own role.');
                }
                if ($previousRole === RoleSlug::Owner && $role->slug !== RoleSlug::Owner && $user->isActive()) {
                    $this->assertAnotherOwnerRemains($user);
                }
                $user->role_id = $role->getKey();
            }

            $user->fill(array_filter([
                'name' => $data['name'] ?? null,
                'email' => isset($data['email']) ? Str::lower($data['email']) : null,
                'locale' => $data['locale'] ?? null,
            ], static fn ($v): bool => $v !== null));

            if ($user->isDirty()) {
                $new = $user->getDirty();
                $user->save();
                if (isset($new['email'])) {
                    // Someone else moved the account to another address: the old one hears of it, every sign-in ends.
                    $this->terminateAccess($user, $actor);
                    $previous = (string) $old['email'];
                    $notice = new SignInEmailChanged($user->name, $user->email, $actor->user->name ?? 'GiftCard Pro', $user->restaurant->name ?? 'GiftCard Pro');
                    DB::afterCommit(static fn () => Notification::route('mail', $previous)->notify($notice->locale($user->locale ?? (string) config('giftcard.mail_locale'))));
                }
                $this->audit->log('user.updated', $actor, $user, array_intersect_key($old, $new), $new);
                $this->events->record(SecurityEventType::StaffChange, $actor, subject: $user, data: array_filter([
                    'fields' => array_keys($new),
                    'role' => isset($new['role_id']) ? $user->load('role')->roleSlug() : null,
                    'previous_role' => isset($new['role_id']) ? $previousRole : null,
                ], static fn (mixed $v): bool => $v !== null));
            }

            return $user->refresh()->load('role');
        });
    }

    public function deactivate(Actor $actor, User $user): User
    {
        $this->assertManageable($actor, $user);
        if ($user->is($actor->user)) {
            throw new RoleAssignmentException('You cannot deactivate your own account.');
        }

        return DB::transaction(function () use ($actor, $user): User {
            if ($user->roleSlug() === RoleSlug::Owner) {
                $this->assertAnotherOwnerRemains($user);
            }
            $user->forceFill(['status' => UserStatus::Inactive])->save();
            $this->terminateAccess($user, $actor);
            $this->audit->log('user.deactivated', $actor, $user, ['status' => UserStatus::Active], ['status' => UserStatus::Inactive]);
            $this->events->record(SecurityEventType::StaffDeactivate, $actor, subject: $user);

            return $user;
        });
    }

    public function activate(Actor $actor, User $user): User
    {
        $this->assertManageable($actor, $user);

        $user->forceFill(['status' => UserStatus::Active, 'failed_login_attempts' => 0, 'locked_until' => null])->save();
        $this->audit->log('user.activated', $actor, $user, ['status' => UserStatus::Inactive], ['status' => UserStatus::Active]);
        $this->events->record(SecurityEventType::StaffActivate, $actor, subject: $user);

        return $user;
    }

    public function changePassword(Actor $actor, User $user, string $newPassword): void
    {
        DB::transaction(function () use ($actor, $user, $newPassword): void {
            $user->forceFill([
                'password' => Hash::make($newPassword),
                'password_changed_at' => Carbon::now(),
            ])->save();

            // Other browser sessions are signed out by Sanctum's AuthenticateSession middleware, which compares the
            // password hash stored in each session with the new one; tokens and remembered browsers are revoked by
            // the caller (AccessRevoker).
            $this->audit->log('user.password_changed', $actor, $user);
            $this->events->record(SecurityEventType::PasswordChange, $actor, subject: $user, restaurantId: $user->restaurant_id);
        });
    }

    /**
     * Staff who never signed in get their invitation again; everybody else a password reset link.
     */
    public function sendPasswordReset(Actor $actor, User $user): void
    {
        $this->assertManageable($actor, $user);

        if (self::isPendingInvitation($user) && $user->restaurant !== null) {
            $this->sendInvitation($user, $user->restaurant, $actor->user?->name);
            $this->audit->log('user.invitation_resent', $actor, $user);

            return;
        }

        SendPasswordResetLink::dispatch($user->email);
        $this->audit->log('user.password_reset_sent', $actor, $user);
        $this->events->record(SecurityEventType::PasswordResetRequest, $actor, subject: $user);
    }

    /** An account whose owner never chose a password (and never signed in). */
    public static function isPendingInvitation(User $user): bool
    {
        return $user->password_changed_at === null && $user->last_login_at === null;
    }

    private function sendInvitation(User $user, Restaurant $restaurant, ?string $invitedBy): void
    {
        $this->invitations->send($user, $restaurant, $invitedBy);
    }

    private function terminateAccess(User $user, Actor $actor): void
    {
        // Sessions of an inactive user are rejected on the next request by ResolveTenant.
        $user->tokens()->whereNull('revoked_at')->update(['revoked_at' => Carbon::now(), 'revoked_by' => $actor->userId()]);
        $user->forceFill(['remember_token' => Str::random(60)])->save();
    }

    /**
     * A restaurant always keeps an active owner. The owner rows are locked, so two owners deactivating or demoting
     * each other at the same moment are serialised: the second one sees the first change and is refused.
     */
    private function assertAnotherOwnerRemains(User $owner): void
    {
        $active = User::query()
            ->where('restaurant_id', $owner->restaurant_id)
            ->where('status', UserStatus::Active->value)
            ->whereHas('role', static fn ($q) => $q->where('slug', RoleSlug::Owner->value))
            ->lockForUpdate()
            ->pluck('id');

        if ($active->reject(static fn (string $id): bool => $id === $owner->getKey())->isEmpty()) {
            throw new LastOwnerException;
        }
    }

    private function assertAssignable(Actor $actor, Role $role): void
    {
        $user = $actor->user;
        if ($user === null) {
            return; // system / console
        }
        if ($role->slug->isPlatform() && ! $user->isPlatformAdmin()) {
            throw new RoleAssignmentException;
        }
        if (! $user->isPlatformAdmin() && ! $user->canManageRole($role)) {
            throw new RoleAssignmentException;
        }
    }

    private function assertManageable(Actor $actor, User $target): void
    {
        $user = $actor->user;
        if ($user === null || $user->isPlatformAdmin() || $user->is($target)) {
            return;
        }
        if (! $user->belongsToRestaurant($target->restaurant_id) || ! $user->canManageRole($target->role)) {
            throw new RoleAssignmentException('You are not allowed to manage this user.');
        }
    }
}
