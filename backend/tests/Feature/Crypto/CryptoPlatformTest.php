<?php

declare(strict_types=1);

namespace Tests\Feature\Crypto;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;
use App\Crypto\Local\LocalCryptoProvider;
use App\Crypto\Local\LocalKeystore;
use App\Crypto\Ntag424\An10922;
use App\Crypto\Ntag424\CardAuthenticator;
use App\Crypto\Ntag424\CardKeys;
use App\Crypto\Ntag424\Ev2FirstAuthentication;
use App\Crypto\Ntag424\SunVerifier;
use App\Crypto\Primitives\Aes;
use App\Exceptions\Domain\CardAuthenticationFailedException;
use Illuminate\Support\Carbon;
use Symfony\Component\Finder\Finder;
use Tests\TestCase;

/** Phase 1: the crypto provider, its keystore commands, and the card operations built on it. */
final class CryptoPlatformTest extends TestCase
{
    private string $keystorePath;

    protected function setUp(): void
    {
        parent::setUp();
        $this->keystorePath = sys_get_temp_dir().'/gcp-feature-ks-'.bin2hex(random_bytes(6)).'/keystore.json';
        config([
            'crypto.provider' => 'local',
            'crypto.local.keystore_path' => $this->keystorePath,
            'crypto.local.master_key' => 'base64:'.base64_encode(random_bytes(32)),
        ]);
        $this->app->forgetInstance(LocalKeystore::class);
        $this->app->forgetInstance(CryptoProvider::class);
    }

    protected function tearDown(): void
    {
        @unlink($this->keystorePath);
        @rmdir(dirname($this->keystorePath));
        parent::tearDown();
    }

    public function test_operators_create_the_keystore_and_keys_without_ever_seeing_material(): void
    {
        $this->artisan('crypto:keystore:init')->assertSuccessful();
        $this->artisan('crypto:key:generate', ['reference' => 'ks-2026-01/sdm-meta-read'])->assertSuccessful();
        $this->artisan('crypto:key:import', ['reference' => 'ks-2026-01/sdm-file-read', '--kcv' => '66E94B'])
            ->expectsQuestion('Key (32 hex characters)', str_repeat('0', 32))
            ->expectsOutputToContain('KCV 66E94B')
            ->assertSuccessful();
        $this->artisan('crypto:key:import', ['reference' => 'ks-2026-01/app-key-0', '--kcv' => 'ABCDEF'])
            ->expectsQuestion('Key (32 hex characters)', str_repeat('1', 32))
            ->assertFailed();
        $this->artisan('crypto:key:list')->expectsOutputToContain('ks-2026-01/sdm-file-read')->assertSuccessful();

        $provider = $this->app->make(CryptoProvider::class);
        $this->assertInstanceOf(LocalCryptoProvider::class, $provider);
        $this->assertSame('66E94B', $provider->keyCheckValue(new KeyReference('ks-2026-01/sdm-file-read')));
        $this->assertFalse($provider->has(new KeyReference('ks-2026-01/app-key-0')));
    }

    public function test_the_master_key_can_be_rotated(): void
    {
        $this->artisan('crypto:keystore:init')->assertSuccessful();
        $this->artisan('crypto:key:generate', ['reference' => 'ks-1/a'])->assertSuccessful();
        $new = base64_encode(random_bytes(32));
        putenv('CRYPTO_KEYSTORE_NEW_KEY=base64:'.$new);
        try {
            $this->artisan('crypto:keystore:rekey')->assertSuccessful();
        } finally {
            putenv('CRYPTO_KEYSTORE_NEW_KEY');
        }

        $this->assertArrayHasKey('ks-1/a', (new LocalKeystore($this->keystorePath, (string) base64_decode($new)))->read());
    }

    private const BATCH = '0f1e2d3c-4b5a-4968-8776-655443322110';

    private function keySet(): CardKeys
    {
        $this->artisan('crypto:keystore:init')->assertSuccessful();
        foreach (['k1', 'root-k0', 'root-k2', 'root-k3'] as $role) {
            $this->artisan('crypto:key:generate', ['reference' => 'ks-1/'.$role])->assertSuccessful();
        }

        return new CardKeys($this->app->make(CryptoProvider::class), 'ks-1', self::BATCH);
    }

    public function test_a_card_tap_is_verified_with_per_card_keys_derived_root_batch_card(): void
    {
        $keys = $this->keySet();
        $provider = $this->app->make(CryptoProvider::class);
        $uid = (string) hex2bin('04A39493CC8680');

        // What a personalised card would put into its tap URL.
        $picc = "\xC7".$uid."\x05\x00\x00".random_bytes(5);
        $e = strtoupper(bin2hex($provider->encryptCbc($keys->metaReadKey(), Aes::ZERO_IV, $picc)));
        $m = SunVerifier::mac($keys->sdmMacKey($uid), $uid, "\x05\x00\x00");

        $message = (new SunVerifier($provider))->verify($keys->metaReadKey(), $keys->sdmMacKey(...), $e, $m);
        $this->assertSame('04A39493CC8680', $message->uid);
        $this->assertSame(5, $message->readCounter);

        // Two AN10922 levels: root (provider) → batch → card; every card and every slot has its own key.
        $batchKey = An10922::fromProvider($provider, new KeyReference('ks-1/root-k3'), 'B'.hex2bin(str_replace('-', '', self::BATCH))."\x03");
        $this->assertSame(An10922::fromKey($batchKey, $uid."\x03GiftCardPro"), $keys->challengeKey($uid));
        $this->assertNotSame($keys->challengeKey($uid), $keys->challengeKey((string) hex2bin('04A39493CC8681')));
        $this->assertNotSame($keys->challengeKey($uid), $keys->sdmMacKey($uid));
        $this->assertNotSame($keys->challengeKey($uid), (new CardKeys($provider, 'ks-1', '1f1e2d3c-4b5a-4968-8776-655443322110'))->challengeKey($uid));
    }

    public function test_live_authentication_is_single_use_and_expires_after_30_seconds(): void
    {
        $keys = $this->keySet();
        $authenticator = $this->app->make(CardAuthenticator::class);
        $uid = (string) hex2bin('04DE5F1EACC040');
        $cardKey = $keys->challengeKey($uid);

        // A simulated card holding its derived K3.
        $rndB = random_bytes(16);
        $cardAnswer = static function (string $response) use ($cardKey, $rndB): string {
            $plain = Aes::decryptCbc($cardKey, Aes::ZERO_IV, $response);
            if (! hash_equals(Ev2FirstAuthentication::rotate($rndB), substr($plain, 16))) {
                throw new \RuntimeException('card refuses');
            }

            return Aes::encryptCbc($cardKey, Aes::ZERO_IV, "\x01\x02\x03\x04".Ev2FirstAuthentication::rotate(substr($plain, 0, 16)).str_repeat("\0", 12));
        };

        $begun = $authenticator->begin($keys, $uid, Aes::encryptCbc($cardKey, Aes::ZERO_IV, $rndB));
        $answer = $cardAnswer($begun['response']);
        $session = $authenticator->finish($keys, $begun['challenge'], $answer);
        $this->assertSame('01020304', bin2hex($session->transactionId));

        try {
            $authenticator->finish($keys, $begun['challenge'], $answer);
            $this->fail('A challenge was finished twice.');
        } catch (CardAuthenticationFailedException) {
            $this->addToAssertionCount(1);
        }

        $late = $authenticator->begin($keys, $uid, Aes::encryptCbc($cardKey, Aes::ZERO_IV, $rndB));
        Carbon::setTestNow(Carbon::now()->addSeconds(CardAuthenticator::LIFETIME_SECONDS + 1));
        $this->expectException(CardAuthenticationFailedException::class);
        $authenticator->finish($keys, $late['challenge'], $cardAnswer($late['response']));
    }

    public function test_no_key_is_configured_in_the_environment_and_only_the_crypto_module_touches_ciphers(): void
    {
        $example = (string) file_get_contents(base_path('.env.example'));
        $this->assertDoesNotMatchRegularExpression('/^NTAG424_/m', $example);
        $this->assertNull(config('giftcard.nfc'));

        // Architecture rule: every use of a secret key goes through App\Crypto (the CryptoProvider).
        $offenders = [];
        foreach ((new Finder)->files()->in(app_path())->name('*.php')->notPath('Crypto') as $file) {
            if (preg_match('/\bopenssl_(encrypt|decrypt)\b|\bhash_hmac\s*\(\s*[\'"]sha256[\'"]\s*,\s*\$uid/', $file->getContents()) === 1) {
                $offenders[] = $file->getRelativePathname();
            }
        }
        $this->assertSame([], $offenders);
    }
}
