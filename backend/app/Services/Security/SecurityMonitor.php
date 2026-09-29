<?php

declare(strict_types=1);

namespace App\Services\Security;

use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType as T;
use App\Models\SecurityAlert;
use App\Models\SecurityEvent;
use App\Support\OpsAlert;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Fraud and attack detection over the security event stream (ADR-003): every new event is matched against the
 * rules below; a rule that fires raises an alert, or counts up the open alert of the same rule and subject.
 * High and critical alerts are e-mailed to operations once per alert. Runs every minute; it only reads the
 * stream and never changes money, so a rule can be strict without hurting a guest.
 *
 * Rules are either instant (one event is enough: a cloned card, a stolen app token, a counterfeit chip) or
 * counted (a threshold of matching events for the same subject within a window: guessing, brute force, limits).
 */
final class SecurityMonitor
{
    private const CURSOR = 'fraud';

    private const BATCH = 5000;

    /** An open alert of the same rule and subject absorbs repeats for this long. */
    private const DEDUP_MINUTES = 60;

    /** @return int events processed */
    public function run(): int
    {
        $cursor = (int) DB::table('security_monitor_cursors')->where('name', self::CURSOR)->value('seq');
        /** @var Collection<int, SecurityEvent> $events */
        $events = SecurityEvent::query()->where('seq', '>', $cursor)->orderBy('seq')->limit(self::BATCH)->get();

        foreach ($events as $event) {
            foreach ($this->rules() as $rule) {
                if (! ($rule['match'])($event)) {
                    continue;
                }
                $subject = ($rule['subject'])($event);
                if (isset($rule['threshold']) && $this->count($rule, $event, $subject) < $rule['threshold']) {
                    continue;
                }
                $this->raise($rule['name'], $rule['severity'], $event, $subject);
            }
            $cursor = $event->seq;
        }
        DB::table('security_monitor_cursors')->updateOrInsert(['name' => self::CURSOR], ['seq' => $cursor, 'updated_at' => Carbon::now()]);

        return $events->count();
    }

    /**
     * @return list<array{name: string, severity: string, match: \Closure(SecurityEvent): bool, subject: \Closure(SecurityEvent): ?string, threshold?: int, window?: int, same?: \Closure(Builder<SecurityEvent>, SecurityEvent): mixed}>
     */
    private function rules(): array
    {
        $refused = static fn (SecurityEvent $e, T $type, string $reasonPrefix): bool => $e->type === $type
            && $e->outcome === SecurityEventOutcome::Refused
            && str_starts_with((string) $e->reason, $reasonPrefix);
        $card = static fn (SecurityEvent $e): ?string => is_string($e->data['card_number'] ?? null) ? 'card:'.$e->data['card_number'] : null;
        $user = static fn (SecurityEvent $e): ?string => $e->user_id !== null ? 'user:'.$e->user_id : null;
        $deviceOrUser = static fn (SecurityEvent $e): ?string => $e->device_id !== null ? 'device:'.$e->device_id : ($e->user_id !== null ? 'user:'.$e->user_id : null);
        $network = static fn (SecurityEvent $e): ?string => $e->ip_network !== null ? 'network:'.$e->ip_network : null;
        $restaurant = static fn (SecurityEvent $e): ?string => $e->restaurant_id !== null ? 'restaurant:'.$e->restaurant_id : null;

        return [
            // A card's URL presented on another chip: a cloned NDEF (anti-cloning refused it).
            ['name' => 'card.clone_attempt', 'severity' => 'critical', 'subject' => $card,
                'match' => static fn (SecurityEvent $e): bool => $refused($e, T::CardAuthenticate, 'CARD_AUTHENTICATION_FAILED:rf_uid_mismatch')],
            // The same genuine card's URL replayed again and again: someone collected it.
            ['name' => 'card.url_replay', 'severity' => 'high', 'subject' => $card, 'threshold' => 3, 'window' => 60,
                'match' => static fn (SecurityEvent $e): bool => $refused($e, T::CardTap, 'SUN_REPLAYED') && $card($e) !== null],
            // Many reads between two verified taps: the card is being read somewhere else (skimming).
            ['name' => 'card.counter_gap', 'severity' => 'warning', 'subject' => $card,
                'match' => static fn (SecurityEvent $e): bool => $e->type === T::CardTap && $e->outcome === SecurityEventOutcome::Succeeded
                    && (int) ($e->data['counter_gap'] ?? 0) >= (int) config('giftcard.fraud.counter_gap', 50)],
            // A chip that is not a genuine NXP NTAG 424 DNA at the station.
            ['name' => 'card.counterfeit', 'severity' => 'critical', 'subject' => static fn (SecurityEvent $e): ?string => $e->data['batch_code'] ?? $card($e),
                'match' => static fn (SecurityEvent $e): bool => $refused($e, T::CardPersonalize, 'CARD_PERSONALIZATION_FAILED:not_genuine')],
            ['name' => 'card.unknown_keys', 'severity' => 'high', 'subject' => $card,
                'match' => static fn (SecurityEvent $e): bool => $refused($e, T::CardPersonalize, 'CARD_PERSONALIZATION_FAILED:auth:91AE')],
            // An app token used from another phone: the token was copied.
            ['name' => 'device.token_theft', 'severity' => 'critical', 'subject' => $user,
                'match' => static fn (SecurityEvent $e): bool => $refused($e, T::DeviceTokenUse, 'OTHER_DEVICE')],
            ['name' => 'auth.account_locked', 'severity' => 'warning', 'subject' => static fn (SecurityEvent $e): ?string => $e->subject_id !== null ? 'user:'.$e->subject_id : null,
                'match' => static fn (SecurityEvent $e): bool => $e->type === T::AccountLock],
            // Many wrong passwords from one network, across accounts: credential stuffing.
            ['name' => 'auth.credential_stuffing', 'severity' => 'high', 'subject' => $network, 'threshold' => 20, 'window' => 10,
                'match' => static fn (SecurityEvent $e): bool => $refused($e, T::SignIn, 'invalid_credentials') && $network($e) !== null],
            // Unknown QR codes or cards from one phone: guessing credentials.
            ['name' => 'presentment.guessing', 'severity' => 'high', 'subject' => $deviceOrUser, 'threshold' => 15, 'window' => 10,
                'match' => static fn (SecurityEvent $e): bool => ($refused($e, T::VoucherScan, 'MEDIUM_NOT_RECOGNIZED') || $refused($e, T::CardAuthenticate, 'SUN_VERIFICATION_FAILED')) && $deviceOrUser($e) !== null],
            // Debits running into the per-transaction, daily or velocity limits.
            ['name' => 'money.limit_hits', 'severity' => 'warning', 'subject' => $restaurant, 'threshold' => 3, 'window' => 60,
                'match' => static fn (SecurityEvent $e): bool => ($refused($e, T::VoucherRedeem, 'VELOCITY_LIMIT_EXCEEDED') || $refused($e, T::VoucherRedeem, 'DEBIT_LIMIT_EXCEEDED')) && $restaurant($e) !== null],
            // One person correcting many bookings in a day.
            ['name' => 'money.reversals', 'severity' => 'warning', 'subject' => $user, 'threshold' => 5, 'window' => 1440,
                'match' => static fn (SecurityEvent $e): bool => $e->type === T::VoucherReverse && $e->outcome === SecurityEventOutcome::Succeeded && $user($e) !== null],
            // One person giving away many vouchers in a day.
            ['name' => 'money.complimentary', 'severity' => 'warning', 'subject' => $user, 'threshold' => 5, 'window' => 1440,
                'match' => static fn (SecurityEvent $e): bool => $e->type === T::VoucherIssue && $e->outcome === SecurityEventOutcome::Succeeded
                    && ($e->data['payment_method'] ?? null) === 'complimentary' && ($e->data['replayed'] ?? false) !== true && $user($e) !== null],
        ];
    }

    /** @param array{match: \Closure(SecurityEvent): bool, subject: \Closure(SecurityEvent): ?string, window?: int} $rule */
    private function count(array $rule, SecurityEvent $event, ?string $subject): int
    {
        $since = $event->occurred_at->copy()->subMinutes($rule['window'] ?? 60);
        $candidates = SecurityEvent::query()
            ->where('type', $event->type->value)
            ->where('occurred_at', '>=', $since)
            ->where('seq', '<=', $event->seq)
            ->when($event->restaurant_id !== null, static fn ($q) => $q->where('restaurant_id', $event->restaurant_id))
            ->orderByDesc('seq')
            ->limit(1000)
            ->get();

        return $candidates->filter(static fn (SecurityEvent $e): bool => ($rule['match'])($e) && ($rule['subject'])($e) === $subject)->count();
    }

    private function raise(string $rule, string $severity, SecurityEvent $event, ?string $subject): void
    {
        /** @var SecurityAlert|null $open */
        $open = SecurityAlert::query()->where('rule', $rule)->where('subject', $subject)->where('status', 'open')
            ->where('last_seen_at', '>=', $event->occurred_at->copy()->subMinutes(self::DEDUP_MINUTES))
            ->first();
        if ($open !== null) {
            if ($open->last_event_seq < $event->seq) {
                $open->forceFill(['occurrences' => $open->occurrences + 1, 'last_event_seq' => $event->seq, 'last_seen_at' => $event->occurred_at])->save();
            }

            return;
        }

        $alert = SecurityAlert::query()->create([
            'rule' => $rule,
            'severity' => $severity,
            'restaurant_id' => $event->restaurant_id,
            'subject' => $subject,
            'occurrences' => 1,
            'first_event_seq' => $event->seq,
            'last_event_seq' => $event->seq,
            'first_seen_at' => $event->occurred_at,
            'last_seen_at' => $event->occurred_at,
            'status' => 'open',
        ]);
        Log::warning('Security alert', ['rule' => $rule, 'severity' => $severity, 'subject' => $subject, 'alert' => $alert->id]);

        if ($severity !== 'warning') {
            $this->notify($alert);
        }
    }

    private function notify(SecurityAlert $alert): void
    {
        OpsAlert::send(
            'security-alert:'.$alert->id,
            "{$alert->severity}: {$alert->rule}",
            "Rule: {$alert->rule} ({$alert->severity})\nSubject: {$alert->subject}\nFirst seen: {$alert->first_seen_at->toIso8601String()}\n\n"
            ."Open the platform dashboard → Security alerts, or `php artisan giftcard:export-security-events` from event {$alert->first_event_seq}.",
        );
    }
}
