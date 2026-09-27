<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customers\StoreCustomerRequest;
use App\Http\Resources\CustomerResource;
use App\Http\Resources\GiftCardResource;
use App\Models\Customer;
use App\Models\NotificationLog;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

final class CustomerController extends Controller
{
    public function __construct(private readonly AuditLogger $audit) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate(['search' => ['nullable', 'string', 'max:100']]);

        $customers = Customer::query()
            ->search($request->string('search')->toString() ?: null)
            ->whereNull('anonymized_at')
            ->withCount('giftCards')
            ->withSum('giftCards', 'balance')
            ->orderBy('last_name')
            ->orderBy('first_name')
            ->paginate($this->perPage($request))
            ->withQueryString();

        return CustomerResource::collection($customers);
    }

    public function store(StoreCustomerRequest $request): JsonResponse
    {
        $customer = new Customer;
        $customer->fill($request->validated())->save();

        $this->audit->log('customer.created', Actor::fromRequest($request), $customer);

        return CustomerResource::make($customer)->response()->setStatusCode(201);
    }

    public function show(Customer $customer): JsonResponse
    {
        $customer->loadCount('giftCards')->loadSum('giftCards', 'balance');

        return response()->json([
            'data' => CustomerResource::make($customer)->resolve(),
            'gift_cards' => GiftCardResource::collection($customer->giftCards()->latest()->limit(100)->get())->resolve(),
        ]);
    }

    public function update(StoreCustomerRequest $request, Customer $customer): CustomerResource
    {
        abort_if($customer->anonymized_at !== null, 409, 'Anonymized customers cannot be edited.');

        $customer->fill($request->validated());
        if ($customer->isDirty()) {
            $old = array_intersect_key($customer->getOriginal(), $customer->getDirty());
            $new = $customer->getDirty();
            $customer->save();
            $this->audit->log('customer.updated', Actor::fromRequest($request), $customer, $old, $new);
        }

        return CustomerResource::make($customer);
    }

    /**
     * GDPR erasure: personal data is irreversibly removed while the card ledger stays intact.
     */
    public function anonymize(Request $request, Customer $customer): CustomerResource
    {
        DB::transaction(function () use ($request, $customer): void {
            $customer->forceFill([
                'first_name' => null,
                'last_name' => null,
                'email' => null,
                'phone' => null,
                'notes' => null,
                'marketing_consent' => false,
                'anonymized_at' => Carbon::now(),
            ])->save();

            $customer->giftCards()->update(['recipient_name' => null]);

            // The e-mail address also lives in the delivery log of notifications sent to this customer.
            NotificationLog::query()
                ->whereIn('gift_card_id', $customer->giftCards()->select('id'))
                ->update(['recipient' => '[anonymized]']);

            $this->audit->log('customer.anonymized', Actor::fromRequest($request), $customer);
        });

        return CustomerResource::make($customer);
    }
}
