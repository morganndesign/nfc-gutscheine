<?php

declare(strict_types=1);

namespace App\Services\Restaurants;

use App\Enums\RestaurantStatus;
use App\Enums\RoleSlug;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\InvitationNotPossibleException;
use App\Exceptions\Domain\RestaurantNotDeletableException;
use App\Models\Customer;
use App\Models\Device;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Models\PersonalAccessToken;
use App\Models\Restaurant;
use App\Models\RestaurantSetting;
use App\Models\User;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Audit\AuditLogger;
use App\Services\Security\SecurityEventRecorder;
use App\Services\Users\InvitationService;
use App\Services\Users\UserService;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Platform-level restaurant (tenant) lifecycle:
 *   create (+ owner invitation) → update → suspend / reactivate ("disable") → archive / restore
 *   → delete (only without business data).
 */
final class RestaurantService
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly UserService $users,
        private readonly InvitationService $invitations,
        private readonly SecurityEventRecorder $events,
    ) {}

    /**
     * @param  array<string, mixed>  $data
     * @param  array{name: string, email: string, password?: string|null}  $owner
     * @return array{restaurant: Restaurant, owner: User}
     */
    public function create(Actor $actor, array $data, array $owner): array
    {
        return DB::transaction(function () use ($actor, $data, $owner): array {
            $restaurant = new Restaurant;
            $restaurant->fill($data);
            $restaurant->slug = $this->uniqueSlug((string) ($data['slug'] ?? $data['name']));
            $restaurant->status = RestaurantStatus::Active;
            $restaurant->save();

            if (isset($data['settings']) && is_array($data['settings'])) {
                $restaurant->settings->fill($data['settings'])->save();
            }

            $ownerUser = $this->users->create($actor, $restaurant, [
                'name' => $owner['name'],
                'email' => $owner['email'],
                'password' => $owner['password'] ?? null,
                'role' => RoleSlug::Owner->value,
            ]);

            $this->audit->log('restaurant.created', $actor, $restaurant, null, $restaurant->only(['name', 'slug', 'currency', 'timezone']), restaurantId: $restaurant->getKey());

            return ['restaurant' => $restaurant->load('settings'), 'owner' => $ownerUser];
        });
    }

    /** @param array<string, mixed> $data */
    public function update(Actor $actor, Restaurant $restaurant, array $data): Restaurant
    {
        if (isset($data['currency']) && $data['currency'] !== $restaurant->currency
            && Voucher::query()->withoutGlobalScopes()->where('restaurant_id', $restaurant->getKey())->exists()) {
            throw ValidationException::withMessages(['currency' => 'The currency cannot be changed after vouchers were issued.']);
        }

        $restaurant->fill($data);
        $dirty = $restaurant->getDirty();

        if ($dirty !== []) {
            $old = array_intersect_key($restaurant->getOriginal(), $dirty);
            $restaurant->save();
            $this->audit->log('restaurant.updated', $actor, $restaurant, $old, $dirty, restaurantId: $restaurant->getKey());
        }

        return $restaurant;
    }

    public function suspend(Actor $actor, Restaurant $restaurant, string $reason): Restaurant
    {
        $restaurant->forceFill([
            'status' => RestaurantStatus::Suspended,
            'suspended_at' => Carbon::now(),
            'suspension_reason' => $reason,
        ])->save();

        $this->audit->log('restaurant.suspended', $actor, $restaurant, ['status' => RestaurantStatus::Active], ['status' => RestaurantStatus::Suspended], ['reason' => $reason], $restaurant->getKey());
        $this->events->record(SecurityEventType::RestaurantSuspend, $actor, subject: $restaurant, restaurantId: $restaurant->getKey());

        return $restaurant;
    }

    public function reactivate(Actor $actor, Restaurant $restaurant): Restaurant
    {
        $restaurant->forceFill([
            'status' => RestaurantStatus::Active,
            'suspended_at' => null,
            'suspension_reason' => null,
        ])->save();

        $this->audit->log('restaurant.reactivated', $actor, $restaurant, ['status' => RestaurantStatus::Suspended], ['status' => RestaurantStatus::Active], restaurantId: $restaurant->getKey());
        $this->events->record(SecurityEventType::RestaurantReactivate, $actor, subject: $restaurant, restaurantId: $restaurant->getKey());

        return $restaurant;
    }

    /**
     * Archiving hides the restaurant and locks out all of its users and devices (the tenant no longer
     * resolves). All data is kept; restore() brings everything back unchanged.
     */
    public function archive(Actor $actor, Restaurant $restaurant, ?string $reason): Restaurant
    {
        DB::transaction(function () use ($actor, $restaurant, $reason): void {
            $restaurant->delete();
            $this->audit->log('restaurant.archived', $actor, $restaurant, null, null, array_filter(['reason' => $reason]), $restaurant->getKey());
        });

        return $restaurant;
    }

    public function restore(Actor $actor, Restaurant $restaurant): Restaurant
    {
        DB::transaction(function () use ($actor, $restaurant): void {
            $restaurant->restore();
            $this->audit->log('restaurant.restored', $actor, $restaurant, restaurantId: $restaurant->getKey());
        });

        return $restaurant;
    }

    /**
     * Counts of the records that make a restaurant non-deletable.
     *
     * @return array{vouchers: int, transactions: int, customers: int}
     */
    public function businessData(Restaurant $restaurant): array
    {
        $id = $restaurant->getKey();

        return [
            'vouchers' => Voucher::query()->withoutGlobalScopes()->where('restaurant_id', $id)->count(),
            'transactions' => VoucherTransaction::query()->withoutGlobalScopes()->where('restaurant_id', $id)->count(),
            'customers' => Customer::query()->withoutGlobalScopes()->withTrashed()->where('restaurant_id', $id)->count(),
        ];
    }

    /**
     * Permanently deletes a restaurant that has no business data (e.g. created by mistake): its users with
     * their tokens, sessions and pending invitations, devices, settings and own e-mail templates.
     * The audit trail is append-only and is kept; its entries keep the deleted restaurant's id.
     *
     * @throws RestaurantNotDeletableException when vouchers, transactions or customers exist
     */
    public function delete(Actor $actor, Restaurant $restaurant, string $confirmation): void
    {
        if (! hash_equals(Str::lower($restaurant->slug), Str::lower(trim($confirmation)))) {
            throw ValidationException::withMessages(['confirm' => "Type the restaurant's short name \"{$restaurant->slug}\" to confirm."]);
        }

        DB::transaction(function () use ($actor, $restaurant): void {
            $locked = Restaurant::withTrashed()->whereKey($restaurant->getKey())->lockForUpdate()->firstOrFail();
            $counts = $this->businessData($locked);

            if (array_sum($counts) > 0) {
                throw new RestaurantNotDeletableException(sprintf(
                    '%s has %d voucher(s), %d transaction(s) and %d customer(s). These records must be kept, so the restaurant cannot be deleted. Archive it instead.',
                    $locked->name, $counts['vouchers'], $counts['transactions'], $counts['customers'],
                ), $counts);
            }

            $id = $locked->getKey();
            $users = User::withTrashed()->where('restaurant_id', $id)->get(['id', 'email']);
            $userIds = $users->pluck('id')->all();

            PersonalAccessToken::query()->where('restaurant_id', $id)
                ->orWhere(static fn ($q) => $q->where('tokenable_type', (new User)->getMorphClass())->whereIn('tokenable_id', $userIds))
                ->delete();
            DB::table('sessions')->whereIn('user_id', $userIds)->delete();
            DB::table((string) config('auth.passwords.invitations.table'))->whereIn('email', $users->pluck('email')->all())->delete();
            Device::withTrashed()->withoutGlobalScopes()->where('restaurant_id', $id)->forceDelete();
            User::withTrashed()->whereKey($userIds)->forceDelete();
            NotificationTemplate::query()->withoutGlobalScopes()->where('restaurant_id', $id)->delete();
            RestaurantSetting::query()->where('restaurant_id', $id)->delete();
            $locked->forceDelete();

            $this->audit->log('restaurant.deleted', $actor, null, $locked->only(['name', 'slug']), null, [
                'restaurant_id' => $id,
                'users_deleted' => count($userIds),
            ]);
        });
    }

    /**
     * Sends the owner's invitation again (new link; the previous one stops working). While the owner has
     * not accepted it yet, a mistyped name or e-mail address can be corrected at the same time.
     *
     * @param  array{name?: string|null, email?: string|null}  $corrections
     * @return array{owner: User, log: NotificationLog}
     */
    public function resendOwnerInvitation(Actor $actor, Restaurant $restaurant, array $corrections = []): array
    {
        $owner = $restaurant->owner()->first();
        if ($owner === null) {
            throw new InvitationNotPossibleException('This restaurant has no owner account to invite.');
        }

        return ['owner' => $owner, 'log' => $this->resendInvitation($actor, $restaurant, $owner, $corrections)];
    }

    /**
     * A new owner for the restaurant, invited by the platform: the restaurant changes hands, or its only owner lost
     * access (left, e-mail gone). The previous owner stays until the new one deactivates them.
     *
     * @param  array{name: string, email: string}  $owner
     */
    public function inviteOwner(Actor $actor, Restaurant $restaurant, array $owner): User
    {
        if ($restaurant->trashed() || ! $restaurant->isActive()) {
            throw new InvitationNotPossibleException('Enable or restore the restaurant first, otherwise the new owner cannot sign in.');
        }

        return DB::transaction(function () use ($actor, $restaurant, $owner): User {
            $user = $this->users->create($actor, $restaurant, ['name' => $owner['name'], 'email' => $owner['email'], 'role' => RoleSlug::Owner->value]);
            $this->audit->log('restaurant.owner_invited', $actor, $restaurant, null, ['owner' => $user->email], restaurantId: $restaurant->getKey());

            return $user;
        });
    }

    /** @param array{name?: string|null, email?: string|null} $corrections */
    public function resendInvitation(Actor $actor, Restaurant $restaurant, User $user, array $corrections = []): NotificationLog
    {
        if ($restaurant->trashed()) {
            throw new InvitationNotPossibleException('The restaurant is archived. Restore it before inviting anyone.');
        }
        if (! $restaurant->isActive()) {
            throw new InvitationNotPossibleException('The restaurant is disabled. Enable it first, otherwise the invited person cannot sign in.');
        }
        if ($user->restaurant_id !== $restaurant->getKey()) {
            throw new InvitationNotPossibleException('This account does not belong to the restaurant.');
        }
        if (! UserService::isPendingInvitation($user)) {
            throw new InvitationNotPossibleException("{$user->name} has already accepted the invitation. Use \"Send password reset\" if they forgot their password.");
        }
        if (! $user->isActive()) {
            throw new InvitationNotPossibleException("{$user->name}'s account is deactivated.");
        }

        return DB::transaction(function () use ($actor, $restaurant, $user, $corrections): NotificationLog {
            $old = $user->only(['name', 'email']);
            $user->fill(array_filter([
                'name' => $corrections['name'] ?? null,
                'email' => isset($corrections['email']) ? Str::lower((string) $corrections['email']) : null,
            ], static fn ($v): bool => $v !== null && $v !== ''));

            if ($user->isDirty()) {
                $new = $user->getDirty();
                if (isset($new['email'])) {
                    // The old address must not keep a working link.
                    DB::table((string) config('auth.passwords.invitations.table'))->where('email', $old['email'])->delete();
                }
                $user->save();
                $this->audit->log('user.updated', $actor, $user, array_intersect_key($old, $new), $new, restaurantId: $restaurant->getKey());
            }

            $log = $this->invitations->send($user, $restaurant, $actor->user?->name);
            $this->audit->log('user.invitation_resent', $actor, $user, metadata: ['delivery' => $log->status], restaurantId: $restaurant->getKey());

            return $log;
        });
    }

    private function uniqueSlug(string $source): string
    {
        $base = Str::slug($source) ?: 'restaurant';
        $base = Str::limit($base, 60, '');
        $slug = $base;
        $i = 2;

        while (Restaurant::withTrashed()->where('slug', $slug)->exists()) {
            $slug = $base.'-'.$i++;
        }

        return $slug;
    }
}
