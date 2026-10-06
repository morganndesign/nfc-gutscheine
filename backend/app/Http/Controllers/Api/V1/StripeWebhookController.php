<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Online\OnlineOrderService;
use App\Services\Online\PaymentProvider;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * POST /webhooks/stripe: Stripe's Connect events. Only an event whose signature proves it came from Stripe is
 * handled; each one once. Anything else gets a 400 and changes nothing.
 */
final class StripeWebhookController extends Controller
{
    public function __invoke(Request $request, PaymentProvider $provider, OnlineOrderService $orders): JsonResponse
    {
        $event = $provider->verifyWebhook($request->getContent(), (string) $request->header('Stripe-Signature', ''));
        if ($event === null) {
            return response()->json(['message' => 'Invalid signature.'], 400);
        }
        $orders->handle($event);

        return response()->json(['received' => true]);
    }
}
