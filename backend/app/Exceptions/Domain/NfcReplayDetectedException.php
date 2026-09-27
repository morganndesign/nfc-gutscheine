<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class NfcReplayDetectedException extends DomainException
{
    public function errorCode(): string
    {
        return 'NFC_REPLAY_DETECTED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'This NFC read was already used. Please tap the card again.';
    }
}
