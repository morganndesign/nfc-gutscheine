<?php

declare(strict_types=1);

namespace App\Services\Presentments;

use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Enums\PresentmentStatus;
use App\Exceptions\Domain\MediumNotRecognizedException;
use App\Exceptions\Domain\PresentmentInvalidException;
use App\Exceptions\Domain\PresentmentMethodNotAllowedException;
use App\Exceptions\Domain\PresentmentMethodUnavailableException;
use App\Exceptions\Domain\PresentmentThrottledException;
use App\Models\Presentment;
use App\Models\Voucher;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\RateLimiter;
use SensitiveParameter;

/**
 * Presentments (architecture §10.1): proof that a medium was presented to this device and user, now.
 *
 * - Created by a method verifier; valid 60 seconds; single use.
 * - Bound to restaurant, voucher, purpose, user and device (null-safe: a presentment made without a device can
 *   only be used without one, and the other way round).
 * - Consumed atomically (verified → consumed) in the transaction of the operation it authorises.
 *
 * Failed presentments count towards a lockout per restaurant, user and device (audit S7): a busy restaurant
 * behind one public IP address is never locked out by another guest's bad scans.
 */
final class PresentmentService
{
    /** @var array<string, PresentmentVerifier> */
    private array $verifiers = [];

    /**
     * @param  iterable<PresentmentVerifier>  $verifiers
     */
    public function __construct(
        iterable $verifiers,
        private readonly TenantContext $tenant,
        private readonly AuditLogger $audit,
    ) {
        foreach ($verifiers as $verifier) {
            $this->verifiers[$verifier->method()->value] = $verifier;
        }
    }

    public function present(Actor $actor, PresentmentPurpose $purpose, PresentmentMethod $method, #[SensitiveParameter] string $credential): Presentment
    {
        $restaurant = $this->tenant->require();
        $throttleKey = $this->throttleKey($actor, $restaurant->getKey());
        $maxFailures = (int) config('giftcard.security.presentment_failure_limit', 10);

        if (RateLimiter::tooManyAttempts($throttleKey, $maxFailures)) {
            throw new PresentmentThrottledException('', ['retry_after' => RateLimiter::availableIn($throttleKey)]);
        }

        $verifier = $this->verifiers[$method->value] ?? null;
        if ($verifier === null || ! $verifier->supports($purpose)) {
            throw new PresentmentMethodUnavailableException('', ['method' => $method->value, 'purpose' => $purpose->value]);
        }

        $medium = $verifier->resolve($credential, $restaurant);
        if ($medium === null) {
            RateLimiter::hit($throttleKey, (int) config('giftcard.security.presentment_failure_decay_seconds', 300));
            $this->audit->log('presentment.failed', $actor, null, null, null, [
                'method' => $method->value,
                'purpose' => $purpose->value,
                'reason' => 'medium_not_recognized',
            ]);

            throw new MediumNotRecognizedException;
        }

        /** @var Voucher $voucher */
        $voucher = $medium->voucher()->firstOrFail();
        // Each purpose has its own state rule (architecture §10.1); for spending, the voucher's kind decides.
        $refused = match ($purpose) {
            PresentmentPurpose::Spend => ! $voucher->kind->allowsSpendingWith($method),
        };
        if ($refused) {
            $this->audit->log('presentment.failed', $actor, $voucher, null, null, [
                'method' => $method->value,
                'purpose' => $purpose->value,
                'reason' => 'method_not_allowed_for_kind',
            ]);

            throw new PresentmentMethodNotAllowedException('', ['kind' => $voucher->kind->value, 'method' => $method->value]);
        }

        $presentment = new Presentment;
        $presentment->forceFill([
            'restaurant_id' => $restaurant->getKey(),
            'voucher_id' => $voucher->getKey(),
            'medium_id' => $medium->getKey(),
            'purpose' => $purpose,
            'method' => $method,
            'level' => $method->level(),
            'status' => PresentmentStatus::Verified,
            'user_id' => $actor->userId(),
            'device_id' => $actor->deviceId(),
            'expires_at' => Carbon::now()->addSeconds(self::lifetimeSeconds()),
            'created_at' => Carbon::now(),
        ])->save();

        return $presentment->setRelation('voucher', $voucher)->setRelation('medium', $medium);
    }

    /**
     * Consumes a presentment for an operation on `$voucher`. Call inside the operation's transaction, before
     * anything is written; the voucher row must already be locked by the caller.
     *
     * @param  Presentment|null  $presentment  The presentment row, locked FOR UPDATE by the caller
     */
    public function consume(?Presentment $presentment, Actor $actor, Voucher $voucher, PresentmentPurpose $purpose): Presentment
    {
        $reason = match (true) {
            $presentment === null => 'not_found',
            $presentment->status !== PresentmentStatus::Verified => 'already_used',
            $presentment->isExpired() => 'expired',
            $presentment->purpose !== $purpose => 'wrong_purpose',
            $presentment->voucher_id !== $voucher->getKey() => 'wrong_voucher',
            $presentment->user_id !== $actor->userId() => 'other_user',
            $presentment->device_id !== $actor->deviceId() => 'other_device',
            ! $voucher->kind->allowsSpendingWith($presentment->method) => 'method_not_allowed_for_kind',
            ! $presentment->medium()->firstOrFail()->isActive() => 'medium_revoked',
            default => null,
        };

        if ($reason !== null) {
            // Audited by the caller after its transaction has rolled back ({@see self::recordRejection()}).
            throw new PresentmentInvalidException('', ['reason' => $reason]);
        }

        /** @var Presentment $presentment */
        $presentment->forceFill(['status' => PresentmentStatus::Consumed, 'consumed_at' => Carbon::now()])->save();

        return $presentment;
    }

    /** Security event for a refused presentment; written outside the refused operation's transaction. */
    public function recordRejection(Actor $actor, Voucher $voucher, ?string $presentmentId, PresentmentInvalidException $e): void
    {
        $this->audit->log('presentment.rejected', $actor, $voucher, null, null, [
            'presentment_id' => $presentmentId,
            'reason' => $e->context()['reason'] ?? null,
        ]);
    }

    public static function lifetimeSeconds(): int
    {
        return max(1, (int) config('giftcard.security.presentment_lifetime_seconds', 60));
    }

    private function throttleKey(Actor $actor, string $restaurantId): string
    {
        return 'presentment-failures:'.$restaurantId.'|'.($actor->userId() ?? '-').'|'.($actor->deviceId() ?? '-');
    }
}
