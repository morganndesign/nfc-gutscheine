<?php

declare(strict_types=1);

namespace App\Data;

use App\Enums\PaymentMethod;

/**
 * How the money for a sale or reload was received. The amount is always the amount sold or reloaded.
 */
final readonly class PaymentData
{
    public function __construct(
        public PaymentMethod $method,
        /** Terminal receipt number or bank reference; required where {@see PaymentMethod::requiresReference()}. */
        public ?string $reference = null,
        /** Why a voucher is complimentary; required for complimentary. */
        public ?string $reason = null,
    ) {}

    /** @param array{method: string, reference?: string|null, reason?: string|null} $input Validated request input */
    public static function fromArray(array $input): self
    {
        return new self(
            PaymentMethod::from($input['method']),
            isset($input['reference']) && $input['reference'] !== '' ? $input['reference'] : null,
            isset($input['reason']) && $input['reason'] !== '' ? $input['reason'] : null,
        );
    }
}
