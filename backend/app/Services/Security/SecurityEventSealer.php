<?php

declare(strict_types=1);

namespace App\Services\Security;

use App\Models\SecurityEvent;
use App\Models\SecurityEventSeal;
use App\Support\HashChain;
use DateTimeInterface;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Seals the security event stream: every run hashes the events written since the last seal, in `seq` order, and
 * chains the result to the previous seal. Writing an event therefore never waits on a shared chain head (a flood
 * of refused sign-ins cannot slow down redemptions), and the stream is still tamper-evident.
 *
 * Only events older than {@see self::SETTLE_SECONDS} are sealed: an event's `seq` is assigned at insert, but its
 * transaction commits later, so a range is sealed only once every transaction that could still add to it has
 * ended (money transactions are bounded by the database lock timeout, far below this). An event that appears
 * inside a sealed range afterwards changes the range's hash and is reported by {@see self::verify()}.
 */
final class SecurityEventSealer
{
    public const SETTLE_SECONDS = 300;

    /** Upper bound per seal, so one seal stays a bounded amount of work to create and to verify. */
    public const MAX_EVENTS_PER_SEAL = 5000;

    /** Seals everything that has settled. Returns the number of seals written. */
    public function seal(?Carbon $now = null): int
    {
        $cutoff = ($now ?? Carbon::now())->copy()->subSeconds(self::SETTLE_SECONDS);
        $written = 0;

        while (true) {
            $sealed = DB::transaction(function () use ($cutoff): bool {
                // One sealer at a time: the latest seal row is the lock.
                /** @var SecurityEventSeal|null $last */
                $last = SecurityEventSeal::query()->orderByDesc('to_seq')->lockForUpdate()->first();
                $from = ($last->to_seq ?? 0) + 1;

                // The first event that has not settled bounds the range, even when later ones have.
                $firstUnsettled = SecurityEvent::query()->where('seq', '>=', $from)->where('occurred_at', '>', $cutoff)->min('seq');
                $events = SecurityEvent::query()
                    ->where('seq', '>=', $from)
                    ->when($firstUnsettled !== null, static fn ($q) => $q->where('seq', '<', $firstUnsettled))
                    ->orderBy('seq')
                    ->limit(self::MAX_EVENTS_PER_SEAL)
                    ->get();

                if ($events->isEmpty()) {
                    return false;
                }

                /** @var SecurityEvent $lastEvent */
                $lastEvent = $events->last();
                $prev = $last->seal_hash ?? HashChain::GENESIS;
                $eventsHash = self::eventsHash($events->values()->all());
                $seal = new SecurityEventSeal;
                $seal->forceFill([
                    'from_seq' => $from,
                    'to_seq' => $lastEvent->seq,
                    'event_count' => $events->count(),
                    'events_hash' => $eventsHash,
                    'prev_hash' => $prev,
                    'seal_hash' => self::sealHash($prev, $from, $lastEvent->seq, $events->count(), $eventsHash),
                    'sealed_at' => Carbon::now(),
                ])->save();

                return true;
            });

            if (! $sealed) {
                return $written;
            }
            $written++;
        }
    }

    /**
     * Recomputes every seal and checks that no settled event is left unsealed.
     *
     * @return list<string> Problems found; empty when the stream is intact.
     */
    public function verify(?Carbon $now = null): array
    {
        $problems = [];
        $prev = HashChain::GENESIS;
        $expectedFrom = 1;

        foreach (SecurityEventSeal::query()->orderBy('to_seq')->cursor() as $seal) {
            /** @var SecurityEventSeal $seal */
            $where = "security_event_seals#{$seal->id} ({$seal->from_seq}–{$seal->to_seq})";
            if ($seal->from_seq !== $expectedFrom) {
                $problems[] = "{$where}: starts at {$seal->from_seq}, expected {$expectedFrom} (a seal is missing)";
            }
            if ($seal->prev_hash !== $prev) {
                $problems[] = "{$where}: prev_hash does not match the previous seal";
            }

            $events = SecurityEvent::query()->whereBetween('seq', [$seal->from_seq, $seal->to_seq])->orderBy('seq')->get();
            if ($events->count() !== $seal->event_count) {
                $problems[] = "{$where}: holds {$events->count()} events, sealed with {$seal->event_count} (events were added or removed)";
            }
            if (self::eventsHash($events->values()->all()) !== $seal->events_hash) {
                $problems[] = "{$where}: the events do not match their seal (changed, added or removed)";
            }
            if (self::sealHash($seal->prev_hash, $seal->from_seq, $seal->to_seq, $seal->event_count, $seal->events_hash) !== $seal->seal_hash) {
                $problems[] = "{$where}: seal_hash is wrong";
            }

            $prev = $seal->seal_hash;
            $expectedFrom = $seal->to_seq + 1;
        }

        // The next event to seal should never be much older than the settle time: if it is, the sealer has stopped
        // (or rows were inserted behind it).
        /** @var SecurityEvent|null $next */
        $next = SecurityEvent::query()->where('seq', '>=', $expectedFrom)->orderBy('seq')->first();
        if ($next !== null && $next->occurred_at->lessThan(($now ?? Carbon::now())->copy()->subSeconds(self::SETTLE_SECONDS * 6))) {
            $problems[] = "security_events#{$next->seq}: settled since {$next->occurred_at->toIso8601String()} but not sealed (is the sealer running?)";
        }

        return $problems;
    }

    /** @param array<int, SecurityEvent> $events */
    public static function eventsHash(array $events): string
    {
        $context = hash_init('sha256');
        foreach ($events as $event) {
            hash_update($context, hash('sha256', self::canonical($event))."\n");
        }

        return hash_final($context);
    }

    public static function sealHash(string $prev, int $from, int $to, int $count, string $eventsHash): string
    {
        return hash('sha256', $prev.json_encode(['security_events', $from, $to, $count, $eventsHash], JSON_THROW_ON_ERROR));
    }

    /** The same text before and after a database round trip (UTC microseconds, enum values, sorted JSON keys). */
    private static function canonical(SecurityEvent $event): string
    {
        $row = [];
        foreach (SecurityEvent::SEALED_COLUMNS as $column) {
            $value = $event->getAttribute($column);
            $row[$column] = match (true) {
                $value instanceof DateTimeInterface => Carbon::instance($value)->utc()->format('Y-m-d H:i:s.u'),
                $value instanceof \BackedEnum => $value->value,
                is_array($value) => self::sortKeys($value),
                default => $value,
            };
        }

        return json_encode($row, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR);
    }

    /**
     * @param  array<mixed>  $value
     * @return array<mixed>
     */
    private static function sortKeys(array $value): array
    {
        $value = array_map(static fn (mixed $v): mixed => is_array($v) ? self::sortKeys($v) : $v, $value);
        if (! array_is_list($value)) {
            ksort($value, SORT_STRING);
        }

        return $value;
    }

    /** Logs a sealing run for operations. */
    public static function logRun(int $seals): void
    {
        if ($seals > 0) {
            Log::info('Security events sealed', ['seals' => $seals]);
        }
    }
}
