<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class InvitationNotPossibleException extends DomainException
{
    public function errorCode(): string
    {
        return 'INVITATION_NOT_POSSIBLE';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'An invitation cannot be sent to this account.';
    }
}
