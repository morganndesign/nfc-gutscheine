<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

use RuntimeException;

/**
 * Base class for business-rule violations. Rendered as a JSON error with a stable
 * machine-readable `code` that API clients (waiter app, POS integrations) can rely on.
 */
abstract class DomainException extends RuntimeException
{
    /** @param array<string, mixed> $context */
    public function __construct(
        string $message = '',
        protected readonly array $context = [],
    ) {
        parent::__construct($message !== '' ? $message : $this->defaultMessage());
    }

    abstract public function errorCode(): string;

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'The request could not be completed.';
    }

    /** @return array<string, mixed> */
    public function context(): array
    {
        return $this->context;
    }
}
