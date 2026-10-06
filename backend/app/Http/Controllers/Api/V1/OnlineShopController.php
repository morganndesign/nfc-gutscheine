<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\OnlineOrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Online\UpdateOnlineShopRequest;
use App\Models\OnlineOrder;
use App\Models\Restaurant;
use App\Services\Online\OnlineShopService;
use App\Services\Online\PaymentProvider;
use App\Services\Vouchers\QrCodeService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Settings › Online-Shop (owners): the connection to the restaurant's own payment provider account, the shop's offer,
 * and its address. The list of online orders is for everyone who sees vouchers.
 */
final class OnlineShopController extends Controller
{
    public function __construct(
        private readonly OnlineShopService $shops,
        private readonly PaymentProvider $provider,
    ) {}

    public function show(): JsonResponse
    {
        return $this->state($this->tenant()->require());
    }

    public function update(UpdateOnlineShopRequest $request): JsonResponse
    {
        $restaurant = $this->tenant()->require();
        /** @var array{enabled?: bool, amounts?: list<int>, custom_amount?: bool, max_amount?: int, card_pickup?: bool, headline?: string|null, intro?: string|null, terms_url?: string|null, imprint_url?: string|null} $input */
        $input = $request->validated();
        $this->shops->update(Actor::fromRequest($request), $restaurant, $input);

        return $this->state($restaurant);
    }

    /** The provider's onboarding page (the owner enters company and bank details there). */
    public function connect(Request $request): JsonResponse
    {
        $url = $this->shops->connect(Actor::fromRequest($request), $this->tenant()->require());

        return response()->json(['data' => ['url' => $url]])->header('Cache-Control', 'no-store');
    }

    public function refresh(Request $request): JsonResponse
    {
        $restaurant = $this->tenant()->require();
        $account = $this->shops->account($restaurant);
        if ($account !== null) {
            $this->shops->refresh(Actor::fromRequest($request), $account);
        }

        return $this->state($restaurant);
    }

    public function disconnect(Request $request): JsonResponse
    {
        $restaurant = $this->tenant()->require();
        $this->shops->disconnect(Actor::fromRequest($request), $restaurant);

        return $this->state($restaurant);
    }

    /** GET /online-orders?status=&pickup=open: the latest online orders; `pickup=open` the cards still to pick up. */
    public function orders(Request $request): JsonResponse
    {
        $request->validate([
            'status' => ['nullable', 'string', 'in:'.implode(',', OnlineOrderStatus::values())],
            'pickup' => ['nullable', 'string', 'in:open'],
        ]);
        $orders = OnlineOrder::query()
            ->with('voucher:id,voucher_number,status,balance,kind')
            ->when($request->query('status'), static fn ($q, $status) => $q->where('status', $status))
            ->when($request->query('pickup') === 'open', static fn ($q) => $q->where('card_pickup', true)->whereNull('card_picked_up_at')
                ->where('status', OnlineOrderStatus::Paid->value))
            ->where('status', '!=', OnlineOrderStatus::Pending->value)
            ->latest()
            ->limit(100)
            ->get();

        return response()->json(['data' => $orders->map(static fn (OnlineOrder $o): array => [
            'id' => $o->getKey(),
            'status' => $o->status->value,
            'amount' => $o->amount,
            'currency' => $o->currency,
            'buyer_email' => $o->buyer_email,
            'buyer_name' => $o->buyer_name,
            'recipient_name' => $o->recipient_name,
            'card_pickup' => $o->card_pickup,
            'card_pickup_from' => $o->card_pickup ? $o->cardPickupFrom()?->toIso8601String() : null,
            'card_picked_up_at' => $o->card_picked_up_at?->toIso8601String(),
            'paid_at' => $o->paid_at?->toIso8601String(),
            'created_at' => $o->created_at->toIso8601String(),
            'voucher' => $o->voucher !== null ? [
                'id' => $o->voucher->getKey(),
                'voucher_number' => $o->voucher->voucher_number,
                'status' => $o->voucher->status->value,
                'balance' => $o->voucher->balance,
            ] : null,
        ])->all()]);
    }

    private function state(Restaurant $restaurant): JsonResponse
    {
        $shop = $this->shops->shop($restaurant);
        $account = $this->shops->account($restaurant);

        return response()->json(['data' => [
            'configured' => $this->provider->configured(),
            'provider' => $this->provider->name(),
            'account' => $account !== null ? [
                'charges_enabled' => $account->charges_enabled,
                'payouts_enabled' => $account->payouts_enabled,
                'details_submitted' => $account->details_submitted,
                'enabled_at' => $account->enabled_at?->toIso8601String(),
            ] : null,
            'shop' => [
                'enabled' => $shop->enabled,
                'amounts' => $shop->amounts,
                'custom_amount' => $shop->custom_amount,
                'max_amount' => $shop->max_amount,
                'card_pickup' => $shop->card_pickup,
                'headline' => $shop->headline,
                'intro' => $shop->intro,
                'terms_url' => $shop->terms_url,
                'imprint_url' => $shop->imprint_url,
            ],
            'limits' => [
                'min_amount' => (int) $restaurant->settings->min_voucher_value,
                'max_amount' => $this->shops->platformMax($restaurant),
            ],
            'url' => $this->shops->url($restaurant),
            // For tables, windows and menus.
            'qr_svg' => app(QrCodeService::class)->svg($this->shops->url($restaurant)),
        ]]);
    }
}
