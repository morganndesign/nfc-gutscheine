<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Enums\PaymentMethod;
use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Enums\RoleSlug;
use App\Events\VoucherIssued;
use App\Events\VoucherRedeemed;
use App\Events\VoucherReloaded;
use App\Exceptions\Domain\DomainException;
use App\Models\Customer;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Presentments\PresentmentService;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;

/**
 * Demo tenant with realistic data. Every voucher, payment and transaction is created through the service
 * layer, and every redemption consumes a presentment of the voucher's printable QR, exactly as at the till.
 *
 * Logins (password for all: Password123!):
 *   admin@giftcardpro.test    – platform administrator
 *   owner@bellavista.test     – restaurant owner
 *   manager@bellavista.test   – manager
 *   waiter@bellavista.test    – waiter
 *   owner@goldenerhirsch.test – owner of a second restaurant (isolation demo)
 */
final class DemoSeeder extends Seeder
{
    public const PASSWORD = 'Password123!';

    public function run(VoucherService $vouchers, PresentmentService $presentments, TenantContext $tenant): void
    {
        if (User::query()->where('email', 'admin@giftcardpro.test')->exists()) {
            $this->command?->warn('Demo data already present – skipped.');

            return;
        }

        User::factory()->platformAdmin()->create([
            'name' => 'Platform Admin',
            'email' => 'admin@giftcardpro.test',
        ]);

        $bellaVista = $this->restaurant('Trattoria Bella Vista', 'bella-vista', 'Mariahilfer Straße 45', '1060', '#7C2D12');
        $hirsch = $this->restaurant('Gasthaus Goldener Hirsch', 'goldener-hirsch', 'Neubaugasse 12', '1070', '#14532D');

        $owner = $this->staff($bellaVista, RoleSlug::Owner, 'Sofia Romano', 'owner@bellavista.test');
        $manager = $this->staff($bellaVista, RoleSlug::Manager, 'Luca Bianchi', 'manager@bellavista.test');
        $waiter = $this->staff($bellaVista, RoleSlug::Waiter, 'Anna Huber', 'waiter@bellavista.test');
        $this->staff($bellaVista, RoleSlug::Waiter, 'David Novak', 'david@bellavista.test');
        $hirschOwner = $this->staff($hirsch, RoleSlug::Owner, 'Franz Gruber', 'owner@goldenerhirsch.test');

        // E-mails would be queued for every demo voucher otherwise.
        Event::fake([VoucherIssued::class, VoucherRedeemed::class, VoucherReloaded::class]);

        $this->populate($vouchers, $presentments, $tenant, $bellaVista, [$owner, $manager], $waiter, 48);
        $this->populate($vouchers, $presentments, $tenant, $hirsch, [$hirschOwner], $hirschOwner, 12);

        Carbon::setTestNow();
    }

    private function restaurant(string $name, string $slug, string $street, string $zip, string $color): Restaurant
    {
        $restaurant = Restaurant::factory()->create([
            'name' => $name,
            'slug' => $slug,
            'legal_name' => $name.' GmbH',
            'email' => 'office@'.$slug.'.test',
            'address_line1' => $street,
            'postal_code' => $zip,
            'city' => 'Wien',
        ]);
        $restaurant->settings->forceFill(['brand_color' => $color])->save();

        return $restaurant->refresh();
    }

    private function staff(Restaurant $restaurant, RoleSlug $role, string $name, string $email): User
    {
        return User::factory()->forRestaurant($restaurant)->role($role)->create(['name' => $name, 'email' => $email]);
    }

    /**
     * @param  list<User>  $issuers
     */
    private function populate(VoucherService $vouchers, PresentmentService $presentments, TenantContext $tenant, Restaurant $restaurant, array $issuers, User $waiter, int $count): void
    {
        $tenant->runAs($restaurant->load('settings'), static function () use ($vouchers, $presentments, $restaurant, $issuers, $waiter, $count): void {
            $customers = Customer::factory()->count((int) ceil($count / 2))->create(['restaurant_id' => $restaurant->getKey()]);
            $values = [2500, 5000, 5000, 7500, 10000, 10000, 15000, 20000];
            $methods = [PaymentMethod::Cash, PaymentMethod::Cash, PaymentMethod::CardTerminal];
            $realNow = Carbon::now();

            for ($i = 0; $i < $count; $i++) {
                $issuedAt = $realNow->copy()->subDays(random_int(1, 120))->setTime(random_int(11, 21), random_int(0, 59));
                Carbon::setTestNow($issuedAt);

                $issuer = $issuers[array_rand($issuers)];
                $method = $methods[array_rand($methods)];
                $sale = $vouchers->sell(new Actor($issuer), new IssueVoucherData(
                    value: $values[array_rand($values)],
                    payment: new PaymentData($method, $method === PaymentMethod::CardTerminal ? 'T-'.random_int(100000, 999999) : null),
                    idempotencyKey: (string) Str::uuid(),
                    customerId: random_int(0, 100) < 60 ? $customers->random()->getKey() : null,
                    recipientName: random_int(0, 100) < 30 ? fake()->firstName().' '.fake()->lastName() : null,
                    notes: random_int(0, 100) < 15 ? 'Birthday present' : null,
                ));
                $voucher = $sale->voucher;
                $qr = (string) $sale->printable?->payload;

                // Visits: the waiter scans the printed QR, then books the amount.
                $visits = random_int(0, 4);
                $moment = $issuedAt->copy();
                for ($v = 0; $v < $visits && $voucher->balance > 0; $v++) {
                    $moment = $moment->copy()->addDays(random_int(1, 20))->setTime(random_int(12, 22), random_int(0, 59));
                    if ($moment->greaterThan($realNow)) {
                        break;
                    }
                    Carbon::setTestNow($moment);
                    $amount = min($voucher->balance, random_int(8, 90) * 100 + random_int(0, 9) * 10);
                    try {
                        $presentment = $presentments->present(new Actor($waiter), PresentmentPurpose::Spend, PresentmentMethod::PrintableQr, $qr);
                        $voucher = $vouchers->redeem(new Actor($waiter), $voucher, $amount, $presentment->getKey(), (string) Str::uuid(), 'Table '.random_int(1, 24))->voucher;
                    } catch (DomainException) {
                        break;
                    }
                }

                if ($voucher->balance > 0 && random_int(0, 100) < 10 && $moment->copy()->addDay()->lessThan($realNow)) {
                    Carbon::setTestNow($moment->copy()->addDay());
                    try {
                        $voucher = $vouchers->reload(new Actor($issuers[0]), $voucher, 5000, new PaymentData(PaymentMethod::Cash), (string) Str::uuid(), 'Top-up at the bar')->voucher;
                    } catch (DomainException) {
                        // Not reloadable (limit): ignore in demo data.
                    }
                }

                Carbon::setTestNow();

                if ($i === 3) {
                    $vouchers->block(new Actor($issuers[0]), Voucher::query()->findOrFail((string) $voucher->getKey()), 'Reported lost by customer');
                }
            }
        });
    }
}
