<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Support\EnvironmentGuard;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;

final class EnvironmentGuardTest extends TestCase
{
    public function test_production_accepts_https_public_urls(): void
    {
        EnvironmentGuard::assertPublicUrls('production', [
            'app.url' => 'https://app.giftcardpro.at',
            'giftcard.frontend_url' => 'https://app.giftcardpro.at',
        ]);
        $this->addToAssertionCount(1);
    }

    public function test_local_and_testing_are_not_checked(): void
    {
        EnvironmentGuard::assertPublicUrls('local', ['app.url' => 'http://localhost:8000']);
        EnvironmentGuard::assertPublicUrls('testing', ['app.url' => null]);
        $this->addToAssertionCount(1);
    }

    /** @return array<string, array{string, mixed}> */
    public static function badUrls(): array
    {
        return [
            'missing (config fallback)' => ['production', 'http://localhost:3000'],
            'empty' => ['production', ''],
            'null' => ['staging', null],
            'plain http' => ['production', 'http://app.giftcardpro.at'],
            'loopback' => ['staging', 'https://127.0.0.1'],
            'emulator host' => ['production', 'https://10.0.2.2:8000'],
            'dev domain' => ['production', 'https://app.giftcardpro.test'],
            'template placeholder' => ['staging', 'https://<staging-domain>'],
        ];
    }

    #[DataProvider('badUrls')]
    public function test_staging_and_production_refuse_development_urls(string $environment, mixed $url): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('giftcard.frontend_url');
        EnvironmentGuard::assertPublicUrls($environment, ['giftcard.frontend_url' => $url]);
    }
}
