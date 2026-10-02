<?php

declare(strict_types=1);

namespace App\Http\Controllers\Tap;

use App\Enums\CardState;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\VoucherStatus;
use App\Exceptions\Domain\DomainException;
use App\Models\Card;
use App\Models\Medium;
use App\Models\Restaurant;
use App\Models\Voucher;
use App\Services\Cards\TapVerifier;
use App\Support\Actor;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * The page a guest sees when tapping their card with their own phone (architecture §10.3, P3-02): after a
 * SUN-verified tap, the balance, if the restaurant allows it. It shows nothing that identifies the card or the
 * voucher and can never spend: the page has no action.
 */
final class TapPageController
{
    public function __invoke(Request $request, TapVerifier $taps, string $keySet): Response
    {
        $language = GuestCopy::language($request->getPreferredLanguage(['de', 'en', 'bs', 'hr', 'sr']));

        try {
            $card = $taps->verify($keySet, (string) $request->query('e'), (string) $request->query('m'), Actor::fromRequest($request));
        } catch (DomainException) {
            return $this->page($language, null, GuestCopy::for($language)['not_verified'], status: 403);
        }

        /** @var Restaurant $restaurant */
        $restaurant = Restaurant::query()->with('settings')->findOrFail($card->restaurant_id);
        $language = GuestCopy::language($restaurant->locale);
        $copy = GuestCopy::for($language);

        // A card on its way from the station to a guest is "not activated yet"; only a card out of service for good
        // (or refused at QA) is "no longer valid".
        $message = match (true) {
            $card->state === CardState::Active => null,
            $card->state === CardState::Suspended => $copy['suspended'],
            $card->state->isTerminal() || $card->state === CardState::QaFailed => $copy['invalid'],
            default => $copy['not_active'],
        };
        if ($message !== null) {
            return $this->page($language, $restaurant, $message);
        }

        $voucher = $this->voucherOf($card);
        if ($voucher === null) {
            return $this->page($language, $restaurant, $copy['invalid']);
        }
        if ($voucher->status === VoucherStatus::Blocked) {
            return $this->page($language, $restaurant, $copy['blocked']);
        }
        if ($voucher->status === VoucherStatus::Expired) {
            return $this->page($language, $restaurant, $copy['expired']);
        }
        if (! $restaurant->settings->public_balance) {
            return $this->page($language, $restaurant, $copy['ask']);
        }

        $expires = $voucher->expires_at?->timezone($restaurant->timezone)->format('d.m.Y');

        return $this->page($language, $restaurant, null, [
            'balance' => Money::format($voucher->balance, $voucher->currency, $restaurant->locale),
            'validity' => $expires === null ? $copy['no_expiry'] : $copy['valid_until'].' '.$expires,
        ]);
    }

    private function voucherOf(Card $card): ?Voucher
    {
        /** @var Medium|null $medium */
        $medium = Medium::query()->withoutGlobalScopes()
            ->where('card_id', $card->getKey())
            ->where('type', MediumType::NfcCard->value)
            ->where('status', MediumStatus::Active->value)
            ->first();

        /** @var Voucher|null */
        return $medium !== null ? Voucher::query()->withoutGlobalScopes()->find($medium->voucher_id) : null;
    }

    /** @param array{balance: string, validity: string}|null $balance */
    private function page(string $language, ?Restaurant $restaurant, ?string $message, ?array $balance = null, int $status = 200): Response
    {
        return response()
            ->view('tap.balance', [
                'lang' => $language,
                'copy' => GuestCopy::for($language),
                'restaurant' => $restaurant?->name,
                'brand' => $restaurant?->settings->brand_color ?? '#18181B',
                'message' => $message,
                'balance' => $balance,
            ], $status)
            ->header('Cache-Control', 'no-store, private')
            ->header('X-Robots-Tag', 'noindex, nofollow')
            ->header('Referrer-Policy', 'no-referrer');
    }
}
