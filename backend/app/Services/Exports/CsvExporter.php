<?php

declare(strict_types=1);

namespace App\Services\Exports;

use App\Support\CsvSanitizer;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Streams large result sets as CSV without loading them into memory.
 */
final class CsvExporter
{
    /**
     * Formats minor units for spreadsheets: decimal comma for German-speaking locales (Excel in AT/DE/CH
     * would otherwise read "12.50" as a date or text), decimal point otherwise. No thousands separator.
     */
    public function amount(int $minorUnits, string $locale): string
    {
        $decimal = str_starts_with($locale, 'de') ? ',' : '.';

        return number_format($minorUnits / 100, 2, $decimal, '');
    }

    /**
     * Rows come out in primary-key order: time-ordered UUIDs, i.e. in the order they were written. Paging is by key
     * (constant memory, stable while rows are added), and keyset paging is only correct when the key is the only
     * sort, so any order the query brings is dropped: with ORDER BY created_at first, rows whose key is out of step
     * with created_at would be skipped or exported twice at every page boundary.
     *
     * @template TModel of Model
     *
     * @param  Builder<TModel>  $query
     * @param  array<string, callable(TModel): mixed>  $columns  header => value resolver
     */
    public function stream(Builder $query, array $columns, string $filename): StreamedResponse
    {
        $chunk = (int) config('giftcard.exports.chunk_size', 1000);

        return new StreamedResponse(static function () use ($query, $columns, $chunk): void {
            $out = fopen('php://output', 'wb');
            if ($out === false) {
                return;
            }
            // UTF-8 BOM so Excel detects the encoding (umlauts in names).
            fwrite($out, "\xEF\xBB\xBF");
            fputcsv($out, array_keys($columns), ';', '"', '');

            foreach ($query->reorder()->lazyById($chunk) as $model) {
                $row = [];
                foreach ($columns as $resolver) {
                    $row[] = CsvSanitizer::cell($resolver($model));
                }
                fputcsv($out, $row, ';', '"', '');
            }

            fclose($out);
        }, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="'.$filename.'"',
            'Cache-Control' => 'no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
