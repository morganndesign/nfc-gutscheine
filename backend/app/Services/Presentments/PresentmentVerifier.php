<?php

declare(strict_types=1);

namespace App\Services\Presentments;

use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Models\Medium;
use App\Models\Restaurant;
use SensitiveParameter;

/**
 * Proves a medium for one presentment method (architecture §10.1). One implementation per method:
 * `printable_qr` now; `live_auth` with the crypto service; `rotating_qr` and `email_link` with digital vouchers.
 */
interface PresentmentVerifier
{
    public function method(): PresentmentMethod;

    public function supports(PresentmentPurpose $purpose): bool;

    /**
     * The medium of this restaurant that the credential proves, or null when it proves nothing.
     * Must not reveal why (unknown, revoked or foreign look the same).
     */
    public function resolve(#[SensitiveParameter] string $credential, Restaurant $restaurant): ?Medium;
}
