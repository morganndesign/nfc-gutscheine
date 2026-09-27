<?php

declare(strict_types=1);

namespace App\Enums;

enum RoleSlug: string
{
    case PlatformAdmin = 'platform_admin';
    case Owner = 'owner';
    case Manager = 'manager';
    case Waiter = 'waiter';

    public function label(): string
    {
        return match ($this) {
            self::PlatformAdmin => 'Platform Administrator',
            self::Owner => 'Restaurant Owner',
            self::Manager => 'Manager',
            self::Waiter => 'Waiter',
        };
    }

    /** Higher rank may manage users of lower rank. */
    public function rank(): int
    {
        return match ($this) {
            self::PlatformAdmin => 100,
            self::Owner => 30,
            self::Manager => 20,
            self::Waiter => 10,
        };
    }

    public function isPlatform(): bool
    {
        return $this === self::PlatformAdmin;
    }

    /** @return list<Permission> */
    public function defaultPermissions(): array
    {
        return match ($this) {
            self::PlatformAdmin => Permission::cases(),
            self::Owner => array_values(array_filter(
                Permission::cases(),
                static fn (Permission $p): bool => ! $p->isPlatform(),
            )),
            self::Manager => [
                Permission::DashboardView,
                Permission::CardsView,
                Permission::CardsScan,
                Permission::CardsCreate,
                Permission::CardsUpdate,
                Permission::CardsActivate,
                Permission::CardsRedeem,
                Permission::CardsReload,
                Permission::CardsBlock,
                Permission::CardsUnblock,
                Permission::CardsExpire,
                Permission::CardsTransfer,
                Permission::CardsReplace,
                Permission::CardsWriteNfc,
                Permission::CardsExport,
                Permission::TransactionsView,
                Permission::TransactionsReverse,
                Permission::TransactionsExport,
                Permission::CustomersView,
                Permission::CustomersManage,
                Permission::AuditView,
                Permission::DevicesView,
            ],
            self::Waiter => [
                Permission::CardsScan,
                Permission::CardsRedeem,
            ],
        };
    }
}
