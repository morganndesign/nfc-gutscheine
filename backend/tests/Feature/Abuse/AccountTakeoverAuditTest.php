<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\RoleSlug;
use App\Models\PersonalAccessToken;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Production audit (authentication / authorization): ways to turn a narrow credential into a wider one, to keep an
 * account locked, or to exhaust a worker with one request.
 */
final class AccountTakeoverAuditTest extends TestCase
{
    private Restaurant $restaurant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->restaurant = $this->restaurant();
    }

    /** An integration token allowed to manage tokens must not mint a token with rights it does not have itself. */
    public function test_a_token_cannot_mint_a_token_with_more_rights_than_itself(): void
    {
        $owner = $this->staff($this->restaurant, RoleSlug::Owner);
        $narrow = $this->integrationToken($owner, ['api_tokens.manage']);

        $this->withToken($narrow)->postJson('/api/v1/api-tokens', ['name' => 'Wide', 'abilities' => ['users.manage', 'vouchers.sell_complimentary']])
            ->assertForbidden()->assertJsonPath('code', 'ROLE_ASSIGNMENT_FORBIDDEN');
        $this->assertSame(1, PersonalAccessToken::query()->count());

        // Within its own rights it still works.
        $this->app['auth']->forgetGuards();
        $this->withToken($narrow)->postJson('/api/v1/api-tokens', ['name' => 'Same', 'abilities' => ['api_tokens.manage']])->assertCreated();

        // In the dashboard (a session) the role is the limit, as before.
        $this->app['auth']->forgetGuards();
        $this->actingAs($owner, 'web')->postJson('/api/v1/api-tokens', ['name' => 'Wide', 'abilities' => ['users.manage']])->assertCreated();
    }

    /**
     * The current-password check is a password oracle: an integration token (a POS vendor, an accounting tool) could
     * guess the owner's password and, on a hit, set its own and sign in as the owner with every right.
     */
    public function test_an_access_token_cannot_change_the_password(): void
    {
        $owner = $this->staff($this->restaurant, RoleSlug::Owner);
        $token = $this->integrationToken($owner, ['transactions.view']);
        $body = ['current_password' => 'Password123!', 'password' => 'Taken0ver-2026', 'password_confirmation' => 'Taken0ver-2026'];

        $this->withToken($token)->putJson('/api/v1/auth/password', $body)->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');
        $this->assertTrue(Hash::check('Password123!', $owner->refresh()->password));

        $this->app['auth']->forgetGuards();
        $this->actingAs($owner, 'web')->putJson('/api/v1/auth/password', $body)->assertOk();
        $this->assertTrue(Hash::check('Taken0ver-2026', $owner->refresh()->password));
    }

    /** A stolen session must not be able to guess the current password at the general API rate (240/min). */
    public function test_password_change_attempts_are_throttled(): void
    {
        $owner = $this->staff($this->restaurant, RoleSlug::Owner);
        $this->actingAs($owner, 'web');

        foreach (range(1, 5) as $i) {
            $this->putJson('/api/v1/auth/password', ['current_password' => "guess-{$i}", 'password' => 'Taken0ver-2026', 'password_confirmation' => 'Taken0ver-2026'])
                ->assertUnprocessable();
        }

        $this->putJson('/api/v1/auth/password', ['current_password' => 'Password123!', 'password' => 'Taken0ver-2026', 'password_confirmation' => 'Taken0ver-2026'])
            ->assertStatus(429);
        $this->assertTrue(Hash::check('Password123!', $owner->refresh()->password));
    }

    /**
     * After a lockout has run out, one mistyped password must not lock the account again for another quarter of an
     * hour (the counter stayed at the threshold), and an attacker must not keep an account locked with one guess
     * per lockout period.
     */
    public function test_an_expired_lockout_starts_counting_again(): void
    {
        config(['giftcard.security.login_lockout_threshold' => 3, 'giftcard.security.login_lockout_minutes' => 15]);
        $user = $this->staff($this->restaurant, RoleSlug::Manager, ['email' => 'luca@example.com']);

        foreach (range(1, 3) as $i) {
            $this->login('luca@example.com', 'wrong', "10.0.0.{$i}")->assertUnprocessable();
        }
        $this->assertTrue($user->refresh()->isLocked());

        $this->travel(16)->minutes();
        $this->login('luca@example.com', 'typo', '10.0.1.1')->assertUnprocessable();

        $this->assertFalse($user->refresh()->isLocked());
        $this->assertSame(1, $user->failed_login_attempts);
        $this->login('luca@example.com', 'Password123!', '10.0.1.2')->assertOk();
    }

    /**
     * The per-account login limiter (5/min) must bucket every spelling that signs in as the same account. MySQL's
     * utf8mb4_unicode_ci folds case, width and compatibility forms, so "ｏwner@…" and "owner@…" are one account; if the
     * throttle keyed on a plain lower-case, an attacker could cycle fullwidth letters for a fresh bucket per spelling
     * and keep guessing past the limit. The throttle runs before validation, so this holds whatever the DB collation.
     */
    public function test_login_throttle_is_not_bypassed_by_unicode_email_variants(): void
    {
        $this->staff($this->restaurant, RoleSlug::Manager, ['email' => 'owner-throttle@example.com']);

        foreach (range(1, 5) as $i) {
            $this->login('owner-throttle@example.com', 'wrong', '10.9.9.9')->assertUnprocessable();
        }

        // A fullwidth "o" (U+FF4F) and an accented "ó" both fold to the same account under utf8mb4_unicode_ci;
        // the bucket is already spent, so these spellings are throttled too.
        $this->login("\u{FF4F}wner-throttle@example.com", 'wrong', '10.9.9.9')->assertStatus(429);
        $this->login("\u{00F3}wner-throttle@example.com", 'wrong', '10.9.9.9')->assertStatus(429);
    }

    /**
     * A 2 MB PNG can declare 12000 × 12000 pixels: decoding it allocates hundreds of megabytes (PHP-FPM workers have
     * 128 MB), so the dimensions are checked from the header before anything is decoded.
     */
    public function test_a_logo_with_huge_dimensions_is_refused_before_decoding(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $bomb = UploadedFile::fake()->createWithContent('logo.png', $this->sparsePng(12000, 12000));
        $this->assertLessThan(2 * 1024 * 1024, $bomb->getSize());

        $this->post('/api/v1/settings/logo', ['logo' => $bomb], ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('logo');
        $this->assertNull($this->restaurant->settings->refresh()->logo_version);
    }

    /** Full CSV exports are the most expensive reads; a script or a leaked token must not run hundreds a minute. */
    public function test_exports_are_rate_limited(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);

        foreach (range(1, 10) as $i) {
            $this->get('/api/v1/transactions/export')->assertOk();
        }
        $this->getJson('/api/v1/vouchers/export')->assertStatus(429);
    }

    /** @param list<string> $abilities */
    private function integrationToken(User $user, array $abilities): string
    {
        $token = $user->createToken('Integration', $abilities);
        $token->accessToken->forceFill(['restaurant_id' => $user->restaurant_id])->save();

        return $token->plainTextToken;
    }

    private function login(string $email, string $password, string $ip): TestResponse
    {
        $this->app['auth']->forgetGuards();

        return $this->withServerVariables(['REMOTE_ADDR' => $ip])->withHeader('Origin', 'http://localhost:3000')
            ->postJson('/api/v1/auth/login', ['email' => $email, 'password' => $password]);
    }

    /** A valid 1-bit greyscale PNG of the given size whose pixel data compresses to almost nothing. */
    private function sparsePng(int $width, int $height): string
    {
        $chunk = static fn (string $type, string $data): string => pack('N', strlen($data)).$type.$data.pack('N', crc32($type.$data));
        $zlib = deflate_init(ZLIB_ENCODING_DEFLATE, ['level' => 9]);
        $row = str_repeat("\0", 1 + intdiv($width + 7, 8));
        $data = '';
        for ($y = 0; $y < $height; $y++) {
            $data .= deflate_add($zlib, $row, ZLIB_NO_FLUSH);
        }
        $data .= deflate_add($zlib, '', ZLIB_FINISH);

        return "\x89PNG\r\n\x1a\n".$chunk('IHDR', pack('NNCCCCC', $width, $height, 1, 0, 0, 0, 0)).$chunk('IDAT', $data).$chunk('IEND', '');
    }
}
