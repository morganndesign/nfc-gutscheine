<?php

declare(strict_types=1);

namespace App\Enums;

use App\Services\Cards\CardLifecycle;

/**
 * The one stored state of a physical card (architecture §7.1). Only {@see CardLifecycle}
 * changes it, and only along {@see self::next()}.
 */
enum CardState: string
{
    case Manufactured = 'manufactured';
    case Personalized = 'personalized';
    case QaPassed = 'qa_passed';
    case QaFailed = 'qa_failed';
    case InInventory = 'in_inventory';
    case Assigned = 'assigned';
    case Shipped = 'shipped';
    case Delivered = 'delivered';
    case Available = 'available';
    case Bound = 'bound';
    case Active = 'active';
    case Suspended = 'suspended';
    case Replaced = 'replaced';
    case Revoked = 'revoked';
    case Lost = 'lost';
    case Destroyed = 'destroyed';

    /**
     * The allowed transitions (§7.1, including the compromise playbook: every card not yet with a guest can be
     * revoked). No transition leads back from a terminal state; nothing is ever reused (R12).
     *
     * @return list<self>
     */
    public function next(): array
    {
        return match ($this) {
            self::Manufactured => [self::Personalized, self::QaFailed],
            self::Personalized => [self::QaPassed, self::QaFailed],
            self::QaPassed => [self::InInventory, self::QaFailed],
            self::QaFailed => [self::Destroyed],
            self::InInventory => [self::Assigned, self::Revoked],
            self::Assigned => [self::Shipped, self::Revoked],
            self::Shipped => [self::Delivered, self::Lost, self::Revoked],
            self::Delivered => [self::Available, self::Lost, self::Revoked],
            self::Available => [self::Bound, self::Lost, self::Revoked],
            self::Bound => [self::Active, self::Available, self::Revoked],
            self::Active => [self::Suspended, self::Replaced, self::Revoked],
            self::Suspended => [self::Active, self::Replaced, self::Revoked],
            self::Replaced, self::Revoked, self::Lost => [self::Destroyed],
            self::Destroyed => [],
        };
    }

    public function canBecome(self $to): bool
    {
        return in_array($to, $this->next(), true);
    }

    /** Lost, replaced, revoked and destroyed cards never come back (§8.2). */
    public function isTerminal(): bool
    {
        return in_array($this, [self::Lost, self::Replaced, self::Revoked, self::Destroyed], true);
    }

    /** Only a checked-in card in the restaurant's stock can be bound to a voucher. */
    public function canBind(): bool
    {
        return $this === self::Available;
    }

    /** A card spends only while active (and only if its voucher allows). */
    public function canSpend(): bool
    {
        return $this === self::Active;
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
