<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Data\IssueGiftCardData;
use App\Enums\RoleSlug;
use App\Events\GiftCardIssued;
use App\Events\GiftCardRedeemed;
use App\Events\GiftCardReloaded;
use App\Exceptions\Domain\DomainException;
use App\Models\Customer;
use App\Models\GiftCard;
use App\Models\Restaurant;
use App\Models\User;
use App\Services\GiftCards\GiftCardService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Event;

/**
 * Demo tenant with realistic data. Every card and transaction is created through the
 * service layer, so the ledger is fully consistent.
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

    public function run(GiftCardService $cards, TenantContext $tenant): void
    {
        if (User::query()->where('email', 'admin@giftcardpro.test')->exists()) {
            $this->command?->warn('Demo data already present – skipped.');

            return;
        }

        User::factory()->platformAdmin()->create([
            'name' => 'Platform Admin',
            'email' => 'admin@giftcardpro.test',
        ]);

        $bellaVista = $this->restaurant('Trattoria Bella Vista', 'bella-vista', 'Mariahilfer Straße 45', '1060', '#7C2D12', '12');
        $hirsch = $this->restaurant('Gasthaus Goldener Hirsch', 'goldener-hirsch', 'Neubaugasse 12', '1070', '#14532D', '34');

        $owner = $this->staff($bellaVista, RoleSlug::Owner, 'Sofia Romano', 'owner@bellavista.test');
        $manager = $this->staff($bellaVista, RoleSlug::Manager, 'Luca Bianchi', 'manager@bellavista.test');
        $waiter = $this->staff($bellaVista, RoleSlug::Waiter, 'Anna Huber', 'waiter@bellavista.test');
        $this->staff($bellaVista, RoleSlug::Waiter, 'David Novak', 'david@bellavista.test');
        $hirschOwner = $this->staff($hirsch, RoleSlug::Owner, 'Franz Gruber', 'owner@goldenerhirsch.test');

        // Emails would be queued for every demo card otherwise.
        Event::fake([GiftCardIssued::class, GiftCardRedeemed::class, GiftCardReloaded::class]);

        $this->populate($cards, $tenant, $bellaVista, [$owner, $manager], $waiter, 48);
        $this->populate($cards, $tenant, $hirsch, [$hirschOwner], $hirschOwner, 12);

        Carbon::setTestNow();

        // Close cards whose expiration date is already in the past (the scheduler does this nightly).
        $cards->expireDueCards($bellaVista);
        $cards->expireDueCards($hirsch);
    }

    private function restaurant(string $name, string $slug, string $street, string $zip, string $color, string $prefix): Restaurant
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
        $restaurant->settings->forceFill(['brand_color' => $color, 'card_number_prefix' => $prefix])->save();

        return $restaurant->refresh();
    }

    private function staff(Restaurant $restaurant, RoleSlug $role, string $name, string $email): User
    {
        return User::factory()->forRestaurant($restaurant)->role($role)->create(['name' => $name, 'email' => $email]);
    }

    /**
     * @param  list<User>  $issuers
     */
    private function populate(GiftCardService $cards, TenantContext $tenant, Restaurant $restaurant, array $issuers, User $waiter, int $count): void
    {
        $tenant->runAs($restaurant->load('settings'), static function () use ($cards, $restaurant, $issuers, $waiter, $count): void {
            $customers = Customer::factory()->count((int) ceil($count / 2))->create(['restaurant_id' => $restaurant->getKey()]);
            $values = [2500, 5000, 5000, 7500, 10000, 10000, 15000, 20000];
            $realNow = Carbon::now();

            for ($i = 0; $i < $count; $i++) {
                $issuedAt = $realNow->copy()->subDays(random_int(1, 120))->setTime(random_int(11, 21), random_int(0, 59));
                Carbon::setTestNow($issuedAt);

                $issuer = $issuers[array_rand($issuers)];
                $result = $cards->issue(new Actor($issuer), new IssueGiftCardData(
                    value: $values[array_rand($values)],
                    expiresOn: $i === 0 ? $issuedAt->copy()->addDays(2)->format('Y-m-d') : null,
                    useDefaultExpiry: $i !== 0,
                    customerId: random_int(0, 100) < 60 ? $customers->random()->getKey() : null,
                    recipientName: random_int(0, 100) < 30 ? fake()->firstName().' '.fake()->lastName() : null,
                    notes: random_int(0, 100) < 15 ? 'Birthday present' : null,
                ));
                $card = $result->card;

                // Simulate visits.
                $visits = random_int(0, 4);
                $moment = $issuedAt->copy();
                for ($v = 0; $v < $visits && $card->balance > 0; $v++) {
                    $moment = $moment->copy()->addDays(random_int(1, 20))->setTime(random_int(12, 22), random_int(0, 59));
                    if ($moment->greaterThan($realNow)) {
                        break;
                    }
                    Carbon::setTestNow($moment);
                    $amount = min($card->balance, random_int(8, 90) * 100 + random_int(0, 9) * 10);
                    try {
                        $card = $cards->redeem(new Actor($waiter), $card, $amount, reference: 'Table '.random_int(1, 24))->card;
                    } catch (DomainException) {
                        break; // e.g. the short-lived demo card expired in the meantime
                    }
                }

                if ($card->balance > 0 && random_int(0, 100) < 10 && $moment->copy()->addDay()->lessThan($realNow)) {
                    Carbon::setTestNow($moment->copy()->addDay());
                    try {
                        $card = $cards->reload(new Actor($issuers[0]), $card, 5000, note: 'Top-up at the bar')->card;
                    } catch (DomainException) {
                        // not reloadable – ignore in demo data
                    }
                }

                Carbon::setTestNow();

                if ($i === 3) {
                    $cards->block(new Actor($issuers[0]), GiftCard::query()->findOrFail((string) $card->getKey()), 'Reported lost by customer');
                }
            }
        });
    }
}
