<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Support\CsvSanitizer;
use PHPUnit\Framework\TestCase;

final class CsvSanitizerTest extends TestCase
{
    public function test_formula_injection_is_neutralised(): void
    {
        $this->assertSame("'=HYPERLINK(\"http://evil\")", CsvSanitizer::cell('=HYPERLINK("http://evil")'));
        $this->assertSame("'+cmd", CsvSanitizer::cell('+cmd'));
        $this->assertSame("'@SUM(A1)", CsvSanitizer::cell('@SUM(A1)'));
    }

    public function test_numbers_and_plain_values_are_untouched(): void
    {
        $this->assertSame('-12.50', CsvSanitizer::cell('-12.50'));
        $this->assertSame('-12,50', CsvSanitizer::cell('-12,50'));
        $this->assertSame("'-1+2", CsvSanitizer::cell('-1+2'));
        $this->assertSame('Anna', CsvSanitizer::cell('Anna'));
        $this->assertSame('', CsvSanitizer::cell(null));
        $this->assertSame('yes', CsvSanitizer::cell(true));
    }
}
