<?php

declare(strict_types=1);

namespace App\Services\Online;

use App\Models\OnlineOrder;
use App\Models\Restaurant;

/**
 * The payment provider behind online sales. The restaurant is the merchant of record: every charge is made on its
 * own connected account (direct charge) with the platform's key; the restaurant never hands us a key.
 */
interface PaymentProvider
{
    /** The provider's name, stored with accounts, orders and events. */
    public function name(): string;

    /** Whether the platform's key and webhook secret are configured. */
    public function configured(): bool;

    /** Creates the restaurant's connected account; returns its id. */
    public function createAccount(Restaurant $restaurant, string $email): string;

    /** A short-lived link to the provider's own onboarding pages for that account. */
    public function onboardingLink(string $accountId, string $returnUrl, string $refreshUrl): string;

    /** What the provider says about the account now. */
    public function account(string $accountId): ProviderAccount;

    /** Opens the provider's payment page for the order; returns its id and address. */
    public function createCheckout(OnlineOrder $order, string $productName, string $successUrl, string $cancelUrl): ProviderCheckout;

    /** Pays money back to the buyer's card; the key makes a retry the same refund. Returns the refund id. */
    public function refund(string $accountId, string $paymentId, int $amount, string $idempotencyKey): string;

    /**
     * Verifies a webhook's signature and returns the event; null when the signature does not prove it came from the
     * provider (or is too old).
     */
    public function verifyWebhook(string $payload, string $signature): ?ProviderEvent;
}
