<?php

declare(strict_types=1);

namespace App\Data;

use App\Enums\ScanMethod;

final readonly class ScanInput
{
    public function __construct(
        public ScanMethod $method,
        public ?string $token = null,
        public ?string $cardNumber = null,
        public ?string $nfcUid = null,
        public ?string $picc = null,
        public ?string $cmac = null,
    ) {}
}
