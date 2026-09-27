<?php

declare(strict_types=1);

namespace App\Data;

use App\Enums\NfcTagType;

final readonly class IssueGiftCardData
{
    /**
     * @param  string|null  $expiresOn  Last valid day (Y-m-d) in the restaurant's timezone; null = no expiry
     * @param  bool  $useDefaultExpiry  When true (expiry not specified), the restaurant's default validity applies
     * @param  array<string, mixed>|null  $newCustomer  Attributes of a customer to create together with the card
     */
    public function __construct(
        public int $value,
        public ?string $expiresOn = null,
        public bool $useDefaultExpiry = true,
        public ?string $customerId = null,
        public ?string $recipientName = null,
        public ?string $notes = null,
        public bool $activate = true,
        public ?NfcTagType $tagType = null,
        public ?string $idempotencyKey = null,
        public ?array $newCustomer = null,
    ) {}

    /** @param array<string, mixed> $input Validated request input */
    public static function fromArray(array $input, ?string $idempotencyKey = null): self
    {
        $customer = $input['customer'] ?? null;
        $hasCustomer = is_array($customer)
            && array_filter($customer, static fn (mixed $v): bool => $v !== null && $v !== '' && $v !== false) !== [];

        return new self(
            value: (int) $input['value'],
            expiresOn: isset($input['expires_at']) ? (string) $input['expires_at'] : null,
            useDefaultExpiry: ! array_key_exists('expires_at', $input),
            customerId: $input['customer_id'] ?? null,
            recipientName: $input['recipient_name'] ?? null,
            notes: $input['notes'] ?? null,
            activate: (bool) ($input['activate'] ?? true),
            tagType: isset($input['nfc_tag_type']) ? NfcTagType::from((string) $input['nfc_tag_type']) : null,
            idempotencyKey: $idempotencyKey,
            newCustomer: $hasCustomer ? $customer : null,
        );
    }
}
