<?php

declare(strict_types=1);

namespace App\Enums;

enum GiftCardStatus: string
{
    /** Value loaded, but card not yet sold / handed out. Cannot be redeemed. */
    case Inactive = 'inactive';
    case Active = 'active';
    /** Balance reached zero. Can be revived by a reload. */
    case Redeemed = 'redeemed';
    case Blocked = 'blocked';
    case Expired = 'expired';
    /** Replaced by another card (lost / damaged). Terminal. */
    case Replaced = 'replaced';

    public function label(): string
    {
        return match ($this) {
            self::Inactive => 'Inactive',
            self::Active => 'Active',
            self::Redeemed => 'Redeemed',
            self::Blocked => 'Blocked',
            self::Expired => 'Expired',
            self::Replaced => 'Replaced',
        };
    }

    public function isTerminal(): bool
    {
        return in_array($this, [self::Expired, self::Replaced], true);
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
