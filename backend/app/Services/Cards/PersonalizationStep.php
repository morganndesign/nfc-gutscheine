<?php

declare(strict_types=1);

namespace App\Services\Cards;

use App\Models\Card;

/** One round of a station personalisation: the APDUs the phone relays next, or `done` with none. */
final readonly class PersonalizationStep
{
    /** @param list<string> $commands binary APDUs, in order; the phone stops at the first failing one */
    public function __construct(
        public ?string $id,
        public string $stage,
        public array $commands,
        public Card $card,
    ) {}

    public function done(): bool
    {
        return $this->id === null;
    }
}
