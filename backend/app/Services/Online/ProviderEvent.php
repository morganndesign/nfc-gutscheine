<?php

declare(strict_types=1);

namespace App\Services\Online;

/**
 * A verified provider event: its id (each is processed once), type, the connected account it happened on, and the
 * object it is about.
 */
final readonly class ProviderEvent
{
    /** @param array<string, mixed> $object */
    public function __construct(
        public string $id,
        public string $type,
        public ?string $accountId,
        public array $object,
    ) {}
}
