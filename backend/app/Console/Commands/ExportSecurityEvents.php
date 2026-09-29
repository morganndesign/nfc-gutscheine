<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\SecurityEvent;
use App\Models\SecurityEventSeal;
use DateTimeInterface;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

/**
 * Exports the security event stream as JSON Lines, one event per line, in `seq` order. The format is the input
 * of analytics and model training: stable column names, enum values, UTC timestamps with microseconds. Only
 * sealed events are exported by default, so an export never contains rows that could still change the seal.
 */
final class ExportSecurityEvents extends Command
{
    protected $signature = 'giftcard:export-security-events
        {--after= : Only events with a seq greater than this (resume a previous export)}
        {--since= : Only events that occurred at or after this time (ISO 8601)}
        {--restaurant= : Only events of this restaurant id}
        {--include-unsealed : Also export events that are not sealed yet}
        {--output= : Write to this file instead of standard output}';

    protected $description = 'Export security events as JSON Lines for analytics and model training.';

    public function handle(): int
    {
        $sealedUpTo = (int) (SecurityEventSeal::query()->max('to_seq') ?? 0);
        $query = SecurityEvent::query()->orderBy('seq')
            ->when($this->option('after') !== null, fn ($q) => $q->where('seq', '>', (int) $this->option('after')))
            ->when($this->option('since') !== null, fn ($q) => $q->where('occurred_at', '>=', Carbon::parse((string) $this->option('since'))))
            ->when($this->option('restaurant') !== null, fn ($q) => $q->where('restaurant_id', (string) $this->option('restaurant')))
            ->when(! $this->option('include-unsealed'), static fn ($q) => $q->where('seq', '<=', $sealedUpTo));

        $path = $this->option('output');
        $handle = is_string($path) && $path !== '' ? fopen($path, 'wb') : fopen('php://output', 'wb');
        if ($handle === false) {
            $this->error('The output cannot be opened.');

            return self::FAILURE;
        }

        $count = 0;
        foreach ($query->lazyById(1000, 'seq') as $event) {
            /** @var SecurityEvent $event */
            $row = [];
            foreach (SecurityEvent::SEALED_COLUMNS as $column) {
                $value = $event->getAttribute($column);
                $row[$column] = match (true) {
                    $value instanceof DateTimeInterface => Carbon::instance($value)->utc()->format('Y-m-d\TH:i:s.u\Z'),
                    $value instanceof \BackedEnum => $value->value,
                    default => $value,
                };
            }
            fwrite($handle, json_encode($row, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR)."\n");
            $count++;
        }
        fclose($handle);

        if (is_string($path) && $path !== '') {
            $this->info("{$count} event(s) written to {$path}.");
        }

        return self::SUCCESS;
    }
}
