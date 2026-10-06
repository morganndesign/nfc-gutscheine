<?php

declare(strict_types=1);

namespace App\Services\Online;

use App\Models\OnlineOrder;
use App\Models\Restaurant;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Stripe Connect with direct charges (online sales, decision 2026-10-06): the restaurant has its own Stripe account
 * (Standard), connected through Stripe's onboarding; its payments, fees, refunds and disputes are its own. We call
 * Stripe with the platform's key on behalf of the account (`Stripe-Account`) and keep only the account id.
 */
final class StripeProvider implements PaymentProvider
{
    /** Signed webhooks older than this are refused (Stripe's recommended tolerance). */
    private const WEBHOOK_TOLERANCE_SECONDS = 300;

    public function name(): string
    {
        return 'stripe';
    }

    public function configured(): bool
    {
        return filled(config('services.stripe.secret')) && filled(config('services.stripe.webhook_secret'));
    }

    public function createAccount(Restaurant $restaurant, string $email): string
    {
        $account = $this->post('/v1/accounts', [
            'type' => 'standard',
            'country' => $restaurant->country ?: 'AT',
            'email' => $email,
            'business_profile' => ['name' => $restaurant->name],
            'metadata' => ['restaurant_id' => $restaurant->getKey()],
        ], idempotencyKey: 'account-'.$restaurant->getKey());

        return (string) $account['id'];
    }

    public function onboardingLink(string $accountId, string $returnUrl, string $refreshUrl): string
    {
        $link = $this->post('/v1/account_links', [
            'account' => $accountId,
            'return_url' => $returnUrl,
            'refresh_url' => $refreshUrl,
            'type' => 'account_onboarding',
        ]);

        return (string) $link['url'];
    }

    public function account(string $accountId): ProviderAccount
    {
        $account = $this->client()->get('/v1/accounts/'.rawurlencode($accountId))->throw()->json();

        return new ProviderAccount(
            (string) $account['id'],
            (bool) ($account['charges_enabled'] ?? false),
            (bool) ($account['payouts_enabled'] ?? false),
            (bool) ($account['details_submitted'] ?? false),
        );
    }

    public function createCheckout(OnlineOrder $order, string $productName, string $successUrl, string $cancelUrl): ProviderCheckout
    {
        $paymentIntent = ['metadata' => ['order_id' => $order->getKey()]];
        if ($order->application_fee > 0) {
            $paymentIntent['application_fee_amount'] = $order->application_fee;
        }
        $session = $this->post('/v1/checkout/sessions', [
            'mode' => 'payment',
            'line_items' => [[
                'quantity' => 1,
                'price_data' => [
                    'currency' => strtolower($order->currency),
                    'unit_amount' => $order->amount,
                    'product_data' => ['name' => $productName],
                ],
            ]],
            'customer_email' => $order->buyer_email,
            'client_reference_id' => $order->getKey(),
            'metadata' => ['order_id' => $order->getKey()],
            'payment_intent_data' => $paymentIntent,
            'success_url' => $successUrl,
            'cancel_url' => $cancelUrl,
            'expires_at' => $order->expires_at->getTimestamp(),
            'locale' => in_array($order->locale, ['de', 'en'], true) ? $order->locale : 'auto',
        ], account: $order->account_id, idempotencyKey: 'checkout-'.$order->getKey());

        return new ProviderCheckout((string) $session['id'], (string) $session['url']);
    }

    public function refund(string $accountId, string $paymentId, int $amount, string $idempotencyKey): string
    {
        $refund = $this->post('/v1/refunds', [
            'payment_intent' => $paymentId,
            'amount' => $amount,
            'metadata' => ['reason' => 'voucher refunded'],
        ], account: $accountId, idempotencyKey: 'refund-'.$idempotencyKey);

        if (in_array($refund['status'] ?? null, ['failed', 'canceled'], true)) {
            throw new RuntimeException('The refund was refused by the payment provider.');
        }

        return (string) $refund['id'];
    }

    public function verifyWebhook(string $payload, string $signature): ?ProviderEvent
    {
        $secret = (string) config('services.stripe.webhook_secret');
        if ($secret === '' || $signature === '') {
            return null;
        }
        $timestamp = null;
        $signatures = [];
        foreach (explode(',', $signature) as $part) {
            [$key, $value] = array_pad(explode('=', trim($part), 2), 2, '');
            if ($key === 't' && ctype_digit($value)) {
                $timestamp = (int) $value;
            } elseif ($key === 'v1') {
                $signatures[] = $value;
            }
        }
        if ($timestamp === null || $signatures === [] || abs(time() - $timestamp) > self::WEBHOOK_TOLERANCE_SECONDS) {
            return null;
        }
        $expected = hash_hmac('sha256', $timestamp.'.'.$payload, $secret);
        $valid = array_filter($signatures, static fn (string $s): bool => hash_equals($expected, $s)) !== [];
        if (! $valid) {
            return null;
        }

        $event = json_decode($payload, true);
        if (! is_array($event) || ! is_string($event['id'] ?? null) || ! is_string($event['type'] ?? null)) {
            return null;
        }
        $object = $event['data']['object'] ?? [];

        return new ProviderEvent($event['id'], $event['type'], is_string($event['account'] ?? null) ? $event['account'] : null, is_array($object) ? $object : []);
    }

    /**
     * @param  array<string, mixed>  $params
     * @return array<string, mixed>
     *
     * @throws RequestException
     */
    private function post(string $path, array $params, ?string $account = null, ?string $idempotencyKey = null): array
    {
        $request = $this->client()->asForm();
        if ($account !== null) {
            $request = $request->withHeaders(['Stripe-Account' => $account]);
        }
        if ($idempotencyKey !== null) {
            $request = $request->withHeaders(['Idempotency-Key' => $idempotencyKey]);
        }

        /** @var array<string, mixed> */
        return $request->post($path, $params)->throw()->json();
    }

    private function client(): PendingRequest
    {
        $secret = (string) config('services.stripe.secret');
        if ($secret === '') {
            throw new RuntimeException('Online sales are not configured (STRIPE_SECRET).');
        }

        return Http::baseUrl((string) config('services.stripe.api_base'))
            ->withToken($secret)
            ->acceptJson()
            ->timeout(20)
            ->connectTimeout(5)
            // Network trouble and Stripe's own errors are retried (every POST carries an idempotency key).
            ->retry(2, 300, static fn (\Throwable $e): bool => $e instanceof ConnectionException
                || ($e instanceof RequestException && $e->response->serverError()), throw: false);
    }
}
