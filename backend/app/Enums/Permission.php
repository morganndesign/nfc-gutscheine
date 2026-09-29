<?php

declare(strict_types=1);

namespace App\Enums;

enum Permission: string
{
    case DashboardView = 'dashboard.view';

    case VouchersView = 'vouchers.view';
    case VouchersSell = 'vouchers.sell';
    /** Sell without payment (marketing). Owner only; four-eyes for others arrives with authorizations. */
    case VouchersSellComplimentary = 'vouchers.sell_complimentary';
    case VouchersUpdate = 'vouchers.update';
    case VouchersRedeem = 'vouchers.redeem';
    case VouchersReload = 'vouchers.reload';
    case VouchersBlock = 'vouchers.block';
    case VouchersUnblock = 'vouchers.unblock';
    /** Expiry keeps the balance; still owner only, with a reason (audit P7). */
    case VouchersExpire = 'vouchers.expire';
    case VouchersReinstate = 'vouchers.reinstate';
    case VouchersExport = 'vouchers.export';
    /** Pay the remaining balance back and close the voucher: owners only. */
    case VouchersRefund = 'vouchers.refund';
    /** Cancel an unused sale of today (booked by mistake); the money goes back the way it came. */
    case VouchersCancelSale = 'vouchers.cancel_sale';

    /** Physical cards of the restaurant: stock, lifecycle. */
    case CardsView = 'cards.view';
    /** Confirm a card delivery (count + one tapped card). */
    case CardsReceive = 'cards.receive';
    /** Link an available card to a paid voucher. */
    case CardsBind = 'cards.bind';
    /** Suspend, resume, replace (with the old card at hand) and take out of stock the restaurant's cards. */
    case CardsManage = 'cards.manage';
    /** Replace a card that is not at hand (lost, stolen): moves a guest's balance without the old card. Owner only. */
    case CardsReplaceLost = 'cards.replace_lost';

    case TransactionsView = 'transactions.view';
    case TransactionsReverse = 'transactions.reverse';
    /** Reverse a reload one booked oneself (took the money, then took the balance back): owners only (four eyes). */
    case TransactionsReverseOwnReload = 'transactions.reverse_own_reload';
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
    /** Personalise blank cards at the station (internal, Android). */
    case PlatformCardsPersonalize = 'platform.cards.personalize';
    /** Order card batches, move them through production and shipping, approve and resolve them. */
    case PlatformCardsManage = 'platform.cards.manage';

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
