<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Online\StartOrderRequest;
use App\Models\RestaurantLogo;
use App\Services\Online\OnlineOrderService;
use App\Services\Online\OnlineShopService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * The public side of a restaurant's online shop (/g/{slug}): what it offers, an order with the provider's payment
 * page, and the buyer's own order status afterwards. No sign-in; nothing here reveals a voucher.
 */
final class ShopController extends Controller
{
    public function __construct(
        private readonly OnlineShopService $shops,
        private readonly OnlineOrderService $orders,
    ) {}

    public function show(string $slug): JsonResponse
    {
        ['restaurant' => $restaurant, 'shop' => $shop] = $this->shops->open($slug);
        $settings = $restaurant->settings;

        return response()->json(['data' => [
            'restaurant' => [
                'name' => $restaurant->name,
                'slug' => $restaurant->slug,
                'locale' => substr($restaurant->locale, 0, 2),
                'website' => $restaurant->website,
            ],
            'currency' => $restaurant->currency,
            'brand_color' => $settings->brand_color,
            'logo_url' => $settings->logo_version !== null ? '/api/v1/shop/'.$restaurant->slug.'/logo?v='.substr($settings->logo_version, 0, 16) : null,
            'headline' => $shop->headline,
            'intro' => $shop->intro,
            'amounts' => $shop->amounts,
            'custom_amount' => $shop->custom_amount,
            'min_amount' => (int) $settings->min_voucher_value,
            'max_amount' => min($shop->max_amount, $this->shops->platformMax($restaurant)),
            'card_pickup' => $shop->card_pickup,
            'terms_url' => $shop->terms_url,
            'imprint_url' => $shop->imprint_url,
            'validity_months' => $settings->validity_months,
        ]])->header('Cache-Control', 'public, max-age=60');
    }

    public function logo(Request $request, string $slug): Response
    {
        ['restaurant' => $restaurant] = $this->shops->open($slug);
        $logo = RestaurantLogo::query()->whereKey($restaurant->getKey())->first();
        abort_if($logo === null, 404);

        return response((string) base64_decode($logo->data, true), 200, [
            'Content-Type' => $logo->mime,
            'Cache-Control' => 'public, max-age=31536000, immutable',
            'X-Content-Type-Options' => 'nosniff',
            'Content-Security-Policy' => "default-src 'none'",
        ]);
    }

    public function order(StartOrderRequest $request, string $slug): JsonResponse
    {
        /** @var array{amount: int, buyer_email: string, buyer_name?: string|null, recipient_name?: string|null, gift_message?: string|null, card_pickup?: bool, locale?: string|null} $input */
        $input = $request->validated();
        ['order' => $order, 'token' => $token, 'checkout_url' => $url] = $this->orders->start($slug, $input, $request->ip());

        return response()->json(['data' => [
            'order_id' => $order->getKey(),
            'token' => $token,
            'checkout_url' => $url,
        ]], 201)->header('Cache-Control', 'no-store');
    }

    /** The buyer's status page: paid (the voucher is on its way by e-mail), still waiting, or not paid. */
    public function status(Request $request, string $order): JsonResponse
    {
        $found = $this->orders->forBuyer($order, (string) $request->query('token', ''));
        abort_if($found === null, 404);

        return response()->json(['data' => [
            'status' => $found->status->value,
            'amount' => $found->amount,
            'currency' => $found->currency,
            'restaurant' => $found->restaurant->name,
            'card_pickup' => $found->card_pickup,
            'email' => $found->buyer_email,
        ]])->header('Cache-Control', 'no-store');
    }
}
