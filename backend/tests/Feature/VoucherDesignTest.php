<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Restaurant;
use App\Models\RestaurantLogo;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

/**
 * The printed voucher's design: template, format, colours and texts, and the restaurant's logo (owners set them;
 * everyone in the restaurant, the waiter app included, reads the logo).
 */
final class VoucherDesignTest extends TestCase
{
    private Restaurant $restaurant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->restaurant = $this->restaurant();
    }

    private function png(int $w = 400, int $h = 200): UploadedFile
    {
        $img = imagecreatetruecolor($w, $h);
        imagefill($img, 0, 0, (int) imagecolorallocate($img, 200, 30, 40));
        $path = tempnam(sys_get_temp_dir(), 'logo').'.png';
        imagepng($img, $path);

        return new UploadedFile($path, 'logo.png', 'image/png', null, true);
    }

    public function test_an_owner_designs_the_voucher(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);

        $this->putJson('/api/v1/settings/vouchers', [
            'voucher_template' => 'bold',
            'voucher_format' => 'a6',
            'accent_color' => '#D4AF37',
            'voucher_headline' => 'Ein Geschenk für dich',
            'voucher_message' => 'Wir freuen uns auf Ihren Besuch.',
        ])->assertOk()
            ->assertJsonPath('data.voucher_design.template', 'bold')
            ->assertJsonPath('data.voucher_design.format', 'a6')
            ->assertJsonPath('data.voucher_design.accent_color', '#D4AF37')
            ->assertJsonPath('data.voucher_design.headline', 'Ein Geschenk für dich');

        $this->putJson('/api/v1/settings/vouchers', ['voucher_template' => 'comic', 'voucher_format' => 'a3', 'accent_color' => 'gold'])
            ->assertUnprocessable()->assertJsonValidationErrors(['voucher_template', 'voucher_format', 'accent_color']);
        $this->getJson('/api/v1/auth/me')->assertJsonPath('data.restaurant.settings.voucher_design.template', 'bold');
    }

    public function test_the_logo_is_reencoded_versioned_and_readable_by_the_whole_restaurant(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $url = (string) $this->post('/api/v1/settings/logo', ['logo' => $this->png(3000, 1500)], ['Accept' => 'application/json'])
            ->assertOk()->json('data.logo_url');
        $this->assertStringStartsWith('/api/v1/restaurant/logo?v=', $url);

        $logo = RestaurantLogo::query()->findOrFail($this->restaurant->id);
        $this->assertSame([1200, 600, 'image/png'], [$logo->width, $logo->height, $logo->mime]);

        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $response = $this->get($url)->assertOk()->assertHeader('Content-Type', 'image/png')->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->assertSame("\x89PNG", substr((string) $response->getContent(), 0, 4));
        $this->get($url, ['If-None-Match' => (string) $response->headers->get('ETag')])->assertStatus(304);

        // Waiters do not change it; another restaurant does not see it.
        $this->post('/api/v1/settings/logo', ['logo' => $this->png()], ['Accept' => 'application/json'])->assertForbidden();
        $this->actingAsStaff($this->restaurant(), RoleSlug::Owner);
        $this->get('/api/v1/restaurant/logo')->assertNotFound();
    }

    public function test_bad_files_are_refused_and_the_logo_can_be_removed(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $fake = UploadedFile::fake()->createWithContent('logo.png', '<svg onload="alert(1)"></svg>');
        $this->post('/api/v1/settings/logo', ['logo' => $fake], ['Accept' => 'application/json'])->assertUnprocessable();
        $this->post('/api/v1/settings/logo', ['logo' => $this->png(10, 10)], ['Accept' => 'application/json'])->assertUnprocessable();
        $this->post('/api/v1/settings/logo', ['logo' => $this->png()], ['Accept' => 'application/json'])->assertOk();

        $this->deleteJson('/api/v1/settings/logo')->assertOk()->assertJsonPath('data.logo_url', null);
        $this->assertNull(RestaurantLogo::query()->find($this->restaurant->id));
        $this->get('/api/v1/restaurant/logo')->assertNotFound();
    }
}
