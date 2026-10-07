<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\Partner;

use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Enums\TransactionType;
use App\Exceptions\Domain\ConnectionRevokedException;
use App\Exceptions\Domain\PresentmentInvalidException;
use App\Exceptions\Domain\TransactionNotReversibleException;
use App\Http\Controllers\Controller;
use App\Http\Middleware\AuthenticatePartner;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Models\Device;
use App\Models\Partner;
use App\Models\PartnerConnection;
use App\Models\Presentment;
use App\Models\Restaurant;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Partners\PartnerService;
use App\Services\Presentments\CardPresentmentService;
use App\Services\Presentments\PresentmentService;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use App\Support\VoucherNumber;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * The POS partner API (`/api/partner/v1`, decision 2026-10-07): a till system redeems vouchers and gift cards of
 * the restaurants that connected it, inside its own app. Physical cards are authenticated live through the till's
 * NFC reader (the till relays bytes only); printed vouchers are scanned as QR codes. Documentation:
 * docs/partner/ (German, for POS companies).
 */
final class PartnerApiController extends Controller
{
    public function __construct(
        private readonly PartnerService $partners,
        private readonly TenantContext $tenant,
    ) {}

    /** GET /me: which partner this key is, and how many restaurants it reaches. */
    public function me(Request $request): JsonResponse
    {
        $partner = $this->partner($request);

        return $this->json([
            'partner' => ['id' => $partner->id, 'name' => $partner->name],
            'connections' => $partner->connections()->where('status', 'active')->count(),
        ]);
    }

    /** POST /connections: redeems a restaurant's one-time code; the restaurant is connected. */
    public function connect(Request $request): JsonResponse
    {
        $data = $request->validate(['code' => ['required', 'string', 'min:8', 'max:16']]);
        [$connection, $token] = $this->partners->connect($this->partner($request), $this->actor($request), (string) $data['code']);

        // The token for this restaurant's tills, shown once.
        return $this->json($this->connectionData($connection) + ['token' => $token], 201);
    }

    /** POST /connections/{connection}/token: a new token for the restaurant's tills; the old one stops at once. */
    public function rotateToken(Request $request, string $connection): JsonResponse
    {
        $partner = $this->partner($request);
        /** @var PartnerConnection|null $found */
        $found = $partner->connections()->whereKey($connection)->with(['restaurant' => static fn ($q) => $q->with('settings')])->first();
        if ($found === null || ! $found->isActive()) {
            throw new ConnectionRevokedException;
        }
        $token = $this->partners->rotateToken($partner, $this->actor($request), $found);

        return $this->json($this->connectionData($found) + ['token' => $token], 201);
    }

    /** GET /connections: the restaurants that connected this partner (active ones). */
    public function connections(Request $request): JsonResponse
    {
        $connections = $this->partner($request)->connections()->where('status', 'active')
            ->with(['restaurant' => static fn ($q) => $q->with('settings')])->orderBy('connected_at')->get();

        return $this->json($connections->map(fn (PartnerConnection $c): array => $this->connectionData($c))->values()->all());
    }

    /** GET /connection: the restaurant of this connection token, with its redemption rules. */
    public function connection(Request $request): JsonResponse
    {
        return $this->json($this->connectionData($this->connectionOf($request)));
    }

    /** POST /cards/authentications: a gift card, step 1 of its live authentication. */
    public function beginCard(Request $request, CardPresentmentService $cards): JsonResponse
    {
        $data = $request->validate([
            'tap_url' => ['required', 'string', 'max:500'],
            'rf_uid' => ['required', 'string', 'size:14'],
            'challenge' => ['required', 'string', 'size:32'],
        ]);

        return $this->json($cards->begin($this->actor($request), PresentmentPurpose::Spend, (string) $data['tap_url'], (string) $data['rf_uid'], (string) $data['challenge']));
    }

    /** POST /cards/authentications/{authentication}: step 2, the card's answer → the card's voucher. */
    public function completeCard(Request $request, CardPresentmentService $cards, string $authentication): JsonResponse
    {
        // Whatever the card answered (also a refusal): the server decides, and a wrong answer counts as a failure.
        $data = $request->validate(['response' => ['required', 'string', 'max:68', 'regex:/^[0-9A-Fa-f]*$/']]);
        $presentment = $cards->complete($this->actor($request), $authentication, (string) $data['response']);

        return $this->json($this->presentmentData($presentment), 201);
    }

    /** POST /vouchers/scan: a printed (or e-mailed) voucher's QR code → the voucher. */
    public function scan(Request $request, PresentmentService $presentments): JsonResponse
    {
        $data = $request->validate(['code' => ['required', 'string', 'max:500']]);
        $presentment = $presentments->present($this->actor($request), PresentmentPurpose::Spend, PresentmentMethod::PrintableQr, (string) $data['code']);

        return $this->json($this->presentmentData($presentment), 201);
    }

    /** POST /redemptions (Idempotency-Key): debits the presented voucher; the till takes the rest of the bill. */
    public function redeem(Request $request, VoucherService $vouchers): JsonResponse
    {
        $data = $request->validate([
            'presentment_id' => ['required', 'string', 'max:64'],
            'amount' => ['required', 'integer', 'min:1', 'max:10000000'],
            'reference' => ['nullable', 'string', 'max:64'],
            'staff' => ['nullable', 'string', 'max:60'],
        ]);
        /** @var Presentment|null $presentment */
        $presentment = preg_match('/^[0-9a-f-]{36}$/i', (string) $data['presentment_id']) === 1
            ? Presentment::query()->whereKey($data['presentment_id'])->first()
            : null;
        /** @var Voucher|null $voucher */
        $voucher = $presentment?->voucher_id !== null ? Voucher::query()->find($presentment->voucher_id) : null;
        if ($presentment === null || $voucher === null) {
            throw new PresentmentInvalidException('', ['reason' => 'not_found']);
        }
        $staff = isset($data['staff']) && trim((string) $data['staff']) !== '' ? trim((string) $data['staff']) : null;
        $result = $vouchers->redeem(
            $this->actor($request),
            $voucher,
            (int) $data['amount'],
            $presentment->getKey(),
            (string) $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE),
            isset($data['reference']) ? (string) $data['reference'] : null,
            $staff !== null ? 'Kasse: '.$staff : null,
        );

        return $this->json($this->redemptionData($result->transaction, $result->voucher) + ['replayed' => $result->replayed], $result->replayed ? 200 : 201);
    }

    /** GET /redemptions/{idempotencyKey}: did a redemption whose answer was lost go through? */
    public function outcome(Request $request, string $idempotencyKey): JsonResponse
    {
        $transaction = $this->ownRedemptions($request)->where('idempotency_key', $idempotencyKey)->first();
        if ($transaction === null) {
            return $this->json(['status' => 'not_booked']);
        }
        /** @var Voucher $voucher */
        $voucher = Voucher::query()->findOrFail($transaction->voucher_id);

        return $this->json(['status' => 'booked'] + $this->redemptionData($transaction, $voucher));
    }

    /** POST /redemptions/{id}/cancellation: the bill was cancelled; the amount goes back onto the voucher. */
    public function cancel(Request $request, VoucherService $vouchers, string $redemption): JsonResponse
    {
        $data = $request->validate(['reason' => ['required', 'string', 'min:3', 'max:200']]);
        /** @var VoucherTransaction|null $transaction */
        $transaction = preg_match('/^[0-9a-f-]{36}$/i', $redemption) === 1 ? $this->ownRedemptions($request)->whereKey($redemption)->first() : null;
        if ($transaction === null) {
            throw new TransactionNotReversibleException('This redemption was not booked by your till system in this restaurant.', ['reason' => 'not_found']);
        }
        $minutes = (int) config('giftcard.partner.cancel_minutes', 60);
        if ($transaction->created_at->lt(Carbon::now()->subMinutes($minutes))) {
            throw new TransactionNotReversibleException("A redemption is cancelled at the till within {$minutes} minutes; later the restaurant corrects it in its dashboard.", ['reason' => 'too_late', 'minutes' => $minutes]);
        }
        $result = $vouchers->reverse($this->actor($request), $transaction, 'Storno Kasse: '.trim((string) $data['reason']));

        return $this->json([
            'id' => $result->transaction->id,
            'cancelled_redemption_id' => $transaction->id,
            'amount' => $result->transaction->amount,
            'currency' => $result->voucher->currency,
            'balance_after' => $result->voucher->balance,
            'voucher_id' => $result->voucher->id,
            'created_at' => $result->transaction->created_at->toIso8601String(),
        ], 201);
    }

    // ------------------------------------------------------------------ helpers

    /** @return Builder<VoucherTransaction> Redemptions booked by this partner's tills here. */
    private function ownRedemptions(Request $request): Builder
    {
        $connection = $this->connectionOf($request);

        return VoucherTransaction::query()
            ->where('restaurant_id', $connection->restaurant_id)
            ->ofType(TransactionType::Redemption)
            ->whereIn('device_id', Device::query()->withoutGlobalScopes()->where('partner_connection_id', $connection->getKey())->select('id'));
    }

    /** @return array<string, mixed> */
    private function connectionData(PartnerConnection $connection): array
    {
        /** @var Restaurant $restaurant */
        $restaurant = $connection->restaurant;
        $settings = $restaurant->settings;

        return [
            'id' => $connection->id,
            'status' => $connection->status,
            'connected_at' => $connection->connected_at->toIso8601String(),
            'restaurant' => [
                'name' => $restaurant->name,
                'currency' => $restaurant->currency,
                'locale' => $restaurant->locale,
                'timezone' => $restaurant->timezone,
            ],
            'rules' => [
                'allow_partial_redemption' => (bool) $settings->allow_partial_redemption,
                'max_debit_per_transaction' => $settings->max_debit_per_transaction,
            ],
        ];
    }

    /** @return array<string, mixed> */
    private function presentmentData(Presentment $presentment): array
    {
        /** @var Voucher $voucher */
        $voucher = $presentment->voucher;
        $settings = $this->tenant->require()->settings;
        $card = $presentment->relationLoaded('card') ? $presentment->card : null;

        return [
            'presentment_id' => $presentment->id,
            'expires_at' => $presentment->expires_at->toIso8601String(),
            'method' => $presentment->method === PresentmentMethod::LiveAuth ? 'card' : 'qr',
            'voucher' => [
                'id' => $voucher->id,
                'number' => VoucherNumber::format($voucher->voucher_number),
                'status' => $voucher->status->value,
                'balance' => $voucher->balance,
                'currency' => $voucher->currency,
                'expires_at' => $voucher->expires_at?->toIso8601String(),
                'redeemable' => $voucher->isSpendable() && $voucher->balance > 0,
                // The most a redemption is accepted for right now (limits, velocity, whole-voucher rule).
                'max_amount' => app(VoucherService::class)->payableNow($voucher),
            ],
            'card' => $card !== null ? ['number' => $card->card_number] : null,
            'rules' => [
                'allow_partial_redemption' => (bool) $settings->allow_partial_redemption,
                'max_debit_per_transaction' => $settings->max_debit_per_transaction,
            ],
        ];
    }

    /** @return array<string, mixed> */
    private function redemptionData(VoucherTransaction $transaction, Voucher $voucher): array
    {
        return [
            'id' => $transaction->id,
            'amount' => -$transaction->amount,
            'currency' => $transaction->currency,
            'balance_after' => $transaction->balance_after,
            'voucher_id' => $voucher->id,
            'voucher_number' => VoucherNumber::format($voucher->voucher_number),
            'reference' => $transaction->reference,
            'created_at' => $transaction->created_at->toIso8601String(),
        ];
    }

    private function partner(Request $request): Partner
    {
        /** @var Partner */
        return $request->attributes->get(AuthenticatePartner::PARTNER);
    }

    private function connectionOf(Request $request): PartnerConnection
    {
        /** @var PartnerConnection */
        return $request->attributes->get(AuthenticatePartner::CONNECTION);
    }

    private function actor(Request $request): Actor
    {
        $device = $request->attributes->get('device');

        return new Actor(
            user: null,
            device: $device instanceof Device ? $device : null,
            ipAddress: $request->ip(),
            userAgent: mb_substr((string) $request->userAgent(), 0, 500),
            requestId: $request->attributes->get('request_id'),
            atTill: true,
        );
    }

    /** @param array<mixed> $data */
    private function json(array $data, int $status = 200): JsonResponse
    {
        return response()->json(['data' => $data], $status)->header('Cache-Control', 'no-store, private');
    }
}
