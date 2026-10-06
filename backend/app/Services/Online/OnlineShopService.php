<?php

declare(strict_types=1);

namespace App\Services\Online;

use App\Enums\RestaurantStatus;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\OnlinePaymentFailedException;
use App\Exceptions\Domain\OnlineShopUnavailableException;
use App\Models\OnlineShop;
use App\Models\PspAccount;
use App\Models\Restaurant;
use App\Services\Audit\AuditLogger;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Throwable;

/**
 * A restaurant's online shop and its payment provider account (Settings › Online-Shop, owners only). The owner
 * connects the restaurant's own account through the provider's onboarding; we keep its id, never a key.
 */
final class OnlineShopService
{
    public function __construct(
        private readonly PaymentProvider $provider,
        private readonly AuditLogger $audit,
        private readonly SecurityEventRecorder $events,
    ) {}

    /** The shop of the restaurant, with its defaults the first time. */
    public function shop(Restaurant $restaurant): OnlineShop
    {
        /** @var OnlineShop|null $shop */
        $shop = OnlineShop::query()->forRestaurant($restaurant)->first();
        if ($shop !== null) {
            return $shop;
        }
        $shop = new OnlineShop;
        $shop->forceFill([
            'restaurant_id' => $restaurant->getKey(),
            'max_amount' => $this->platformMax($restaurant),
        ]);

        return $shop;
    }

    public function account(Restaurant $restaurant): ?PspAccount
    {
        /** @var PspAccount|null */
        return PspAccount::query()->forRestaurant($restaurant)->first();
    }

    /** The largest online voucher: the platform's cap and the restaurant's own balance limit. */
    public function platformMax(Restaurant $restaurant): int
    {
        return min((int) config('giftcard.online.max_amount', 25000), (int) $restaurant->settings->max_voucher_balance);
    }

    /** The shop's public address. */
    public function url(Restaurant $restaurant): string
    {
        return config('giftcard.frontend_url').'/g/'.$restaurant->slug;
    }

    /**
     * Starts or continues the provider's onboarding: creates the restaurant's account the first time, then returns
     * the provider's page where the owner enters the company and bank details.
     */
    public function connect(Actor $actor, Restaurant $restaurant): string
    {
        $this->assertConfigured();
        $account = $this->account($restaurant);
        try {
            if ($account === null) {
                $id = $this->provider->createAccount($restaurant, (string) ($restaurant->email ?? $actor->user?->email));
                $account = new PspAccount;
                $account->forceFill([
                    'restaurant_id' => $restaurant->getKey(),
                    'provider' => $this->provider->name(),
                    'account_id' => $id,
                    'connected_by' => $actor->userId(),
                ])->save();
                $this->audit->log('online.account_connected', $actor, $account, null, ['provider' => $account->provider, 'account_id' => $id]);
                $this->events->record(SecurityEventType::OnlineAccount, $actor, subject: $account, data: [
                    'provider' => $account->provider, 'status' => 'connected', 'charges_enabled' => false,
                ]);
            }
            $back = config('giftcard.frontend_url').'/settings?tab=online';

            return $this->provider->onboardingLink($account->account_id, $back.'&stripe=return', $back.'&stripe=refresh');
        } catch (OnlineShopUnavailableException $e) {
            throw $e;
        } catch (Throwable $e) {
            report($e);

            throw new OnlinePaymentFailedException;
        }
    }

    /** Reads the account's state from the provider (after the onboarding, or on the provider's `account.updated`). */
    public function refresh(Actor $actor, PspAccount $account): PspAccount
    {
        try {
            $state = $this->provider->account($account->account_id);
        } catch (Throwable $e) {
            report($e);

            throw new OnlinePaymentFailedException;
        }

        return $this->apply($actor, $account, $state);
    }

    public function apply(Actor $actor, PspAccount $account, ProviderAccount $state): PspAccount
    {
        $wasEnabled = $account->charges_enabled;
        $account->forceFill([
            'charges_enabled' => $state->chargesEnabled,
            'payouts_enabled' => $state->payoutsEnabled,
            'details_submitted' => $state->detailsSubmitted,
            'enabled_at' => $state->chargesEnabled ? ($account->enabled_at ?? Carbon::now()) : $account->enabled_at,
        ]);
        if ($account->isDirty()) {
            $account->save();
            if ($wasEnabled !== $state->chargesEnabled) {
                $this->events->record(SecurityEventType::OnlineAccount, $actor, subject: $account, data: [
                    'provider' => $account->provider, 'status' => $state->chargesEnabled ? 'enabled' : 'restricted', 'charges_enabled' => $state->chargesEnabled,
                ]);
            }
        }

        return $account;
    }

    /** Forgets the account (the owner disconnects, or the provider tells us it was disconnected): the shop stops. */
    public function disconnect(Actor $actor, Restaurant $restaurant): void
    {
        DB::transaction(function () use ($actor, $restaurant): void {
            $account = $this->account($restaurant);
            if ($account === null) {
                return;
            }
            OnlineShop::query()->forRestaurant($restaurant)->update(['enabled' => false]);
            $account->delete();
            $this->audit->log('online.account_disconnected', $actor, $account, ['provider' => $account->provider, 'account_id' => $account->account_id], null);
            $this->events->record(SecurityEventType::OnlineAccount, $actor, data: [
                'provider' => $account->provider, 'status' => 'disconnected', 'charges_enabled' => false,
            ], restaurantId: $restaurant->getKey());
        });
    }

    /**
     * Saves the shop's offer. Switching it on needs an account that may take payments and the restaurant's own
     * terms and imprint (the restaurant is the seller).
     *
     * @param  array{enabled?: bool, amounts?: list<int>, custom_amount?: bool, max_amount?: int, card_pickup?: bool, headline?: string|null, intro?: string|null, terms_url?: string|null, imprint_url?: string|null}  $input
     */
    public function update(Actor $actor, Restaurant $restaurant, array $input): OnlineShop
    {
        $shop = $this->shop($restaurant);
        $before = $shop->exists ? $shop->only(['enabled', 'amounts', 'custom_amount', 'max_amount', 'card_pickup', 'headline', 'intro', 'terms_url', 'imprint_url']) : null;
        $shop->fill(array_intersect_key($input, array_flip($shop->getFillable())));
        if (array_key_exists('enabled', $input)) {
            $shop->enabled = (bool) $input['enabled'];
        }

        $max = $this->platformMax($restaurant);
        $min = (int) $restaurant->settings->min_voucher_value;
        $errors = [];
        if ($shop->max_amount > $max || $shop->max_amount < $min) {
            $errors['max_amount'] = __('online.max_amount', ['min' => $min, 'max' => $max]);
        }
        foreach ($shop->amounts as $amount) {
            if ($amount < $min || $amount > $shop->max_amount) {
                $errors['amounts'] = __('online.amounts', ['min' => $min, 'max' => $shop->max_amount]);
            }
        }
        if ($shop->enabled) {
            if (($this->account($restaurant)->charges_enabled ?? false) !== true) {
                $errors['enabled'] = __('online.not_connected');
            } elseif (blank($shop->terms_url) || blank($shop->imprint_url)) {
                $errors['enabled'] = __('online.legal_missing');
            }
        }
        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        $amounts = array_values(array_unique(array_map('intval', $shop->amounts)));
        sort($amounts);
        $shop->amounts = $amounts;
        $shop->save();
        $this->audit->log('online.shop_updated', $actor, $shop, $before, $shop->only(['enabled', 'amounts', 'custom_amount', 'max_amount', 'card_pickup', 'headline', 'intro', 'terms_url', 'imprint_url']));

        return $shop;
    }

    /**
     * The shop a guest sees at /g/{slug}: only an active restaurant whose shop is on and whose account takes
     * payments.
     *
     * @return array{restaurant: Restaurant, shop: OnlineShop, account: PspAccount}
     */
    public function open(string $slug): array
    {
        /** @var Restaurant|null $restaurant */
        $restaurant = Restaurant::query()->where('slug', $slug)->with('settings')->first();
        if ($restaurant === null || $restaurant->status !== RestaurantStatus::Active) {
            throw new OnlineShopUnavailableException('', ['reason' => 'not_found']);
        }
        $shop = $this->shop($restaurant);
        $account = $this->account($restaurant);
        if (! $this->provider->configured()) {
            throw new OnlineShopUnavailableException('', ['reason' => 'not_configured']);
        }
        if (! $shop->exists || ! $shop->enabled || $account === null || ! $account->charges_enabled) {
            throw new OnlineShopUnavailableException('', ['reason' => 'closed']);
        }

        return ['restaurant' => $restaurant, 'shop' => $shop, 'account' => $account];
    }

    private function assertConfigured(): void
    {
        if (! $this->provider->configured()) {
            throw new OnlineShopUnavailableException('Online sales are not configured on this server.', ['reason' => 'not_configured']);
        }
    }
}
