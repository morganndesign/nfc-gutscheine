<?php

declare(strict_types=1);

namespace App\Data;

/**
 * A sale: a printable digital voucher, or a card voucher bound to the card tapped for it (`cardPresentmentId`,
 * a `bind` presentment of an available card).
 */
final readonly class IssueVoucherData
{
    /**
     * @param  array<string, mixed>|null  $newCustomer  Attributes of a customer to create together with the voucher
     */
    public function __construct(
        public int $value,
        public PaymentData $payment,
        public string $idempotencyKey,
        public ?string $customerId = null,
        public ?string $recipientName = null,
        public ?string $notes = null,
        public ?array $newCustomer = null,
        public ?string $cardPresentmentId = null,
    ) {}

    public function isCard(): bool
    {
        return $this->cardPresentmentId !== null;
    }

    /** @param array<string, mixed> $input Validated request input */
    public static function fromArray(array $input, string $idempotencyKey): self
    {
        $customer = $input['customer'] ?? null;
        $hasCustomer = is_array($customer)
            && array_filter($customer, static fn (mixed $v): bool => $v !== null && $v !== '' && $v !== false) !== [];

        /** @var array{method: string, reference?: string|null, reason?: string|null} $payment */
        $payment = $input['payment'];

        return new self(
            value: (int) $input['value'],
            payment: PaymentData::fromArray($payment),
            idempotencyKey: $idempotencyKey,
            customerId: $input['customer_id'] ?? null,
            recipientName: $input['recipient_name'] ?? null,
            notes: $input['notes'] ?? null,
            newCustomer: $hasCustomer ? $customer : null,
            cardPresentmentId: ($input['form'] ?? null) === 'card' ? (string) $input['presentment_id'] : null,
        );
    }
}
