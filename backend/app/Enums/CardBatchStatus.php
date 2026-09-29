<?php

declare(strict_types=1);

namespace App\Enums;

/** Status of a card batch (architecture §8.2). One batch = one restaurant order = one print run = one shipment. */
enum CardBatchStatus: string
{
    case Ordered = 'ordered';
    case InProduction = 'in_production';
    case Personalized = 'personalized';
    case QaTesting = 'qa_testing';
    case Accepted = 'accepted';
    case Rejected = 'rejected';
    case Assigned = 'assigned';
    case Shipped = 'shipped';
    case Delivered = 'delivered';
    case OnHold = 'on_hold';
    case InService = 'in_service';
    case Depleted = 'depleted';
    case Compromised = 'compromised';
    case Lost = 'lost';
    case Closed = 'closed';

    /** @return list<self> */
    public function next(): array
    {
        $next = match ($this) {
            self::Ordered => [self::InProduction],
            self::InProduction => [self::Personalized],
            self::Personalized => [self::QaTesting],
            self::QaTesting => [self::Accepted, self::Rejected],
            self::Accepted => [self::Assigned],
            self::Assigned => [self::Shipped],
            self::Shipped => [self::Delivered, self::Lost],
            self::Delivered => [self::InService, self::OnHold],
            self::OnHold => [self::InService],
            self::InService => [self::Depleted],
            self::Depleted => [self::InService, self::Closed],
            self::Compromised, self::Rejected, self::Lost => [self::Closed],
            self::Closed => [],
        };

        // A key leak can be declared from acceptance onwards (§8.2).
        if (in_array($this, [self::Accepted, self::Assigned, self::Shipped, self::Delivered, self::OnHold, self::InService, self::Depleted], true)) {
            $next[] = self::Compromised;
        }

        return $next;
    }

    public function canBecome(self $to): bool
    {
        return in_array($to, $this->next(), true);
    }

    /**
     * How a batch status change moves its cards: target card state => card states it applies to (§8.2).
     *
     * @return array{0: CardState, 1: list<CardState>}|null
     */
    public function cardMove(): ?array
    {
        return match ($this) {
            self::Accepted => [CardState::InInventory, [CardState::QaPassed]],
            self::Assigned => [CardState::Assigned, [CardState::InInventory]],
            self::Shipped => [CardState::Shipped, [CardState::Assigned]],
            self::Delivered => [CardState::Delivered, [CardState::Shipped]],
            self::Rejected => [CardState::QaFailed, [CardState::Manufactured, CardState::Personalized, CardState::QaPassed]],
            self::Lost => [CardState::Lost, [CardState::Shipped]],
            self::Compromised => [CardState::Revoked, [CardState::InInventory, CardState::Assigned, CardState::Shipped, CardState::Delivered, CardState::Available, CardState::Bound]],
            default => null,
        };
    }
}
