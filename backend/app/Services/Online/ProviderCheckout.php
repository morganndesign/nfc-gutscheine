<?php

declare(strict_types=1);

namespace App\Services\Online;

final readonly class ProviderCheckout
{
    public function __construct(
        public string $id,
        public string $url,
    ) {}
}
