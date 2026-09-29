<?php

declare(strict_types=1);

namespace App\Data;

use App\Models\Medium;
use SensitiveParameter;

/**
 * A freshly issued printable QR. The payload exists only in this object and in the one response that carries it;
 * the database keeps its SHA-256 hash.
 */
final readonly class PrintableSecret
{
    public function __construct(
        public Medium $medium,
        #[SensitiveParameter] public string $payload,
    ) {}
}
