<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Support\Money;
use PHPUnit\Framework\TestCase;

/**
 * Guests read amounts in the restaurant's format. Production printed "€30.00" in a German voucher PDF (2026-10-04)
 * because the image lacked the ICU locale data; the image and its entrypoint now guard that, this test the format.
 */
final class MoneyFormatTest extends TestCase
{
    public function test_amounts_follow_the_restaurant_locale(): void
    {
        $this->assertSame('€ 30,00', str_replace("\u{00A0}", ' ', Money::format(3000, 'EUR', 'de-AT')));
        $this->assertSame('30,00 €', str_replace("\u{00A0}", ' ', Money::format(3000, 'EUR', 'de-DE')));
        $this->assertStringContainsString('30,00', Money::format(3000, 'EUR', 'bs-BA'));
        $this->assertSame('€30.00', Money::format(3000, 'EUR', 'en'));
    }
}
