<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Services\GiftCards\CardUrlBuilder;
use PHPUnit\Framework\TestCase;

final class CardUrlBuilderTest extends TestCase
{
    private const TOKEN = '3f2b6c1e-8d4a-4f7b-9a2c-1e5d7f9b3a6c';

    public function test_extracts_token_from_urls_and_raw_values(): void
    {
        $builder = new CardUrlBuilder;

        $this->assertSame(self::TOKEN, $builder->extractToken('https://app.example.com/c/'.self::TOKEN));
        $this->assertSame(self::TOKEN, $builder->extractToken('https://app.example.com/c/'.strtoupper(self::TOKEN).'?picc=00&cmac=00'));
        $this->assertSame(self::TOKEN, $builder->extractToken(self::TOKEN));
    }

    public function test_rejects_non_v4_or_garbage(): void
    {
        $builder = new CardUrlBuilder;

        $this->assertNull($builder->extractToken('https://evil.example.com/x/'.self::TOKEN.'x'));
        $this->assertNull($builder->extractToken('3f2b6c1e-8d4a-1f7b-9a2c-1e5d7f9b3a6c')); // v1
        $this->assertNull($builder->extractToken("' OR 1=1 --"));
    }
}
