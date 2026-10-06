<?php

declare(strict_types=1);

namespace App\Services\Presentments;

use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Models\Medium;
use App\Models\Restaurant;
use App\Services\Media\PrintableQrService;
use SensitiveParameter;

/**
 * A1 bearer proof: whoever holds the printed QR may spend the voucher, like a paper voucher.
 */
final class PrintableQrVerifier implements PresentmentVerifier
{
    public function method(): PresentmentMethod
    {
        return PresentmentMethod::PrintableQr;
    }

    public function supports(PresentmentPurpose $purpose): bool
    {
        // A printable QR pays, and an online voucher's QR picks up its card; cards are received and bound with a
        // live authentication.
        return $purpose === PresentmentPurpose::Spend || $purpose === PresentmentPurpose::Pickup;
    }

    public function resolve(#[SensitiveParameter] string $credential, Restaurant $restaurant): ?Medium
    {
        $hash = PrintableQrService::hashOf(trim($credential));
        if ($hash === null) {
            return null;
        }

        /** @var Medium|null */
        return Medium::query()
            ->forRestaurant($restaurant)
            ->where('secret_hash', $hash)
            ->where('type', MediumType::PrintableQr->value)
            ->where('status', MediumStatus::Active->value)
            ->first();
    }
}
