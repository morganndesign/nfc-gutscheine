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
            // Platform staff operate the platform (restaurants, batches, stations), never vouchers (architecture §13.1).
            self::PlatformAdmin => array_values(array_filter(
                Permission::cases(),
                static fn (Permission $p): bool => $p->isPlatform(),
            )),
            self::Owner => array_values(array_filter(
                Permission::cases(),
                static fn (Permission $p): bool => ! $p->isPlatform(),
            )),
            self::Manager => [
                Permission::DashboardView,
                Permission::VouchersView,
                Permission::VouchersSell,
                Permission::VouchersUpdate,
                Permission::VouchersRedeem,
                Permission::VouchersReload,
                Permission::VouchersBlock,
                Permission::VouchersUnblock,
                Permission::VouchersExport,
                Permission::VouchersCancelSale,
                Permission::VouchersReissue,
                Permission::CardsView,
                Permission::CardsReceive,
                Permission::CardsBind,
                Permission::CardsManage,
                Permission::TransactionsView,
                Permission::TransactionsReverse,
                Permission::TransactionsExport,
                Permission::CustomersView,
                Permission::CustomersManage,
                Permission::AuditView,
                Permission::DevicesView,
            ],
            self::Waiter => [
                Permission::VouchersRedeem,
            ],
        };
    }
}
