<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Support\VoucherNumber;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class VoucherNumberTest extends TestCase
{
    /** @return iterable<string, array{string, bool}> */
    public static function numbers(): iterable
    {
        yield 'valid visa-like' => ['4539 1488 0343 6467', true];
        yield 'classic luhn example' => ['79927398713', true];
        yield 'one digit off' => ['79927398710', false];
        yield 'too short' => ['1234', false];
    }

    #[DataProvider('numbers')]
    public function test_it_validates_luhn_numbers(string $number, bool $valid): void
    {
        $this->assertSame($valid, VoucherNumber::isValid($number));
    }

    public function test_check_digit_is_computed(): void
    {
        $this->assertSame(3, VoucherNumber::luhnCheckDigit('7992739871'));
    }

    public function test_formatting_and_masking(): void
    {
        $this->assertSame('1234 5678 9012 3456', VoucherNumber::format('1234567890123456'));
        $this->assertSame('1234567890123456', VoucherNumber::normalize('1234-5678 9012.3456'));
        $this->assertSame('•••• 3456', VoucherNumber::mask('1234567890123456'));
    }
}
