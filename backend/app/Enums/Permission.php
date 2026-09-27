<?php

declare(strict_types=1);

namespace App\Enums;

enum Permission: string
{
    case DashboardView = 'dashboard.view';

    case CardsView = 'cards.view';
    case CardsScan = 'cards.scan';
    case CardsCreate = 'cards.create';
    case CardsUpdate = 'cards.update';
    case CardsActivate = 'cards.activate';
    case CardsRedeem = 'cards.redeem';
    case CardsReload = 'cards.reload';
    case CardsBlock = 'cards.block';
    case CardsUnblock = 'cards.unblock';
    case CardsExpire = 'cards.expire';
    case CardsTransfer = 'cards.transfer';
    case CardsReplace = 'cards.replace';
    case CardsWriteNfc = 'cards.write_nfc';
    case CardsExport = 'cards.export';

    case TransactionsView = 'transactions.view';
    case TransactionsReverse = 'transactions.reverse';
    case TransactionsExport = 'transactions.export';

    case CustomersView = 'customers.view';
    case CustomersManage = 'customers.manage';

    case UsersView = 'users.view';
    case UsersManage = 'users.manage';

    case DevicesView = 'devices.view';
    case DevicesManage = 'devices.manage';

    case SettingsManage = 'settings.manage';
    case ApiTokensManage = 'api_tokens.manage';
    case AuditView = 'audit.view';

    case PlatformRestaurantsManage = 'platform.restaurants.manage';
    case PlatformSettingsManage = 'platform.settings.manage';
    case PlatformAuditView = 'platform.audit.view';

    public function group(): string
    {
        return explode('.', $this->value)[0];
    }

    public function isPlatform(): bool
    {
        return $this->group() === 'platform';
    }

    public function label(): string
    {
        return ucfirst(str_replace(['.', '_'], ' ', $this->value));
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
