<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * Status of a card batch (architecture §8.2). One batch = one restaurant order = one print run = one shipment.
 * The main path is in_production → accepted (release) → shipped (ship) → in_service / on_hold (the restaurant's
 * receipt); the other statuses are special transitions set by the platform with a reason.
 */
enum CardBatchStatus: string
{
    case InProduction = 'in_production';
    case Accepted = 'accepted';
    case Rejected = 'rejected';
    case Shipped = 'shipped';
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
            // Before shipping a batch can be stopped (a cancelled order, a leaked key set): its cards never leave.
            self::InProduction => [self::Accepted, self::Rejected],
            self::Accepted => [self::Shipped, self::Rejected],
            self::Shipped => [self::InService, self::OnHold, self::Lost],
            self::OnHold => [self::InService],
            self::InService => [self::Depleted],
            self::Depleted => [self::InService, self::Closed],
            self::Compromised, self::Rejected, self::Lost => [self::Closed],
            self::Closed => [],
        };

        // A key leak can be declared from release onwards (§8.2).
        if (in_array($this, [self::Accepted, self::Shipped, self::OnHold, self::InService, self::Depleted], true)) {
            $next[] = self::Compromised;
        }

        return $next;
    }

    public function canBecome(self $to): bool
    {
        return in_array($to, $this->next(), true);
    }

    /** Statuses reached only through their own step (release, ship, the restaurant's receipt), never set by hand. */
    public function hasOwnStep(): bool
    {
        return in_array($this, [self::Accepted, self::Shipped, self::InService, self::OnHold], true);
    }

    /**
     * How a special status change moves the batch's cards: list of [target card state, card states it applies to]
     * (§8.2). Release, shipping and receipt move their cards themselves.
     *
     * @return list<array{0: CardState, 1: list<CardState>}>
     */
    public function cardMoves(): array
    {
        return match ($this) {
            // Unreleased cards fail QA; released stock cards that never left the platform are revoked.
            self::Rejected => [
                [CardState::QaFailed, [CardState::Manufactured, CardState::Personalized, CardState::QaPassed]],
                [CardState::Revoked, [CardState::InInventory]],
            ],
            self::Lost => [[CardState::Lost, [CardState::Shipped]]],
            self::Compromised => [[CardState::Revoked, [CardState::InInventory, CardState::Assigned, CardState::Shipped, CardState::Delivered, CardState::Available, CardState::Bound]]],
            default => [],
        };
    }
}
