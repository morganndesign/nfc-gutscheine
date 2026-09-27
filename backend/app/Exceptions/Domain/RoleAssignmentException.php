<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class RoleAssignmentException extends DomainException
{
    public function errorCode(): string
    {
        return 'ROLE_ASSIGNMENT_FORBIDDEN';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'You are not allowed to assign this role.';
    }
}
