<?php

declare(strict_types=1);

namespace App\Services\Online;

final readonly class ProviderAccount
{
    public function __construct(
        public string $id,
        public bool $chargesEnabled,
        public bool $payoutsEnabled,
        public bool $detailsSubmitted,
    ) {}
}
