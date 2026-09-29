<?php

declare(strict_types=1);

namespace App\Services\Media;

use App\Data\PrintableSecret;
use App\Enums\MediumRole;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\SecurityEventType;
use App\Enums\VoucherKind;
use App\Exceptions\Domain\InvalidVoucherStateException;
use App\Models\Medium;
use App\Models\Voucher;
use App\Services\Audit\AuditLogger;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use SensitiveParameter;

/**
 * Printable QR media (architecture §10.4): a 256-bit random bearer secret for digital vouchers only, one active
 * per voucher. Only its SHA-256 hash is stored; the payload is returned once, when it is created.
 *
 * Payload: "GCPV1." + base64url(32 random bytes), 49 characters. It is deliberately not a URL, so it never
 * ends up in web server logs or browser histories when a phone camera scans it.
 */
final class PrintableQrService
{
    public const PREFIX = 'GCPV1.';

    private const SECRET_BYTES = 32;

    public function __construct(
        private readonly AuditLogger $audit,
        private readonly SecurityEventRecorder $events,
    ) {}

    /**
     * Issues the voucher's printable QR and revokes a previous one. Must run inside the transaction that
     * holds the voucher's row lock.
     */
    public function issue(Actor $actor, Voucher $voucher, string $reason): PrintableSecret
    {
        if ($voucher->kind !== VoucherKind::Digital) {
            throw new InvalidVoucherStateException('A printable QR can only be issued for a digital voucher.', ['kind' => $voucher->kind->value]);
        }

        $this->revokeActive($actor, $voucher, $reason);

        $secret = random_bytes(self::SECRET_BYTES);
        $payload = self::PREFIX.rtrim(strtr(base64_encode($secret), '+/', '-_'), '=');

        $medium = new Medium;
        $medium->forceFill([
            'restaurant_id' => $voucher->restaurant_id,
            'voucher_id' => $voucher->getKey(),
            'type' => MediumType::PrintableQr,
            'role' => MediumRole::Spend,
            'status' => MediumStatus::Active,
            'secret_hash' => hash('sha256', $secret),
            'created_by' => $actor->userId(),
        ])->save();

        $this->audit->log('medium.issued', $actor, $medium, null, [
            'type' => MediumType::PrintableQr,
            'voucher_id' => $voucher->getKey(),
        ], ['reason' => $reason]);
        $this->events->record(SecurityEventType::MediumIssue, $actor, subject: $voucher, data: [
            'medium_type' => MediumType::PrintableQr,
            'cause' => $reason,
        ]);

        return new PrintableSecret($medium, $payload);
    }

    /**
     * The hash under which a scanned payload's medium is stored, or null when the text is not a printable QR.
     */
    public static function hashOf(#[SensitiveParameter] string $payload): ?string
    {
        if (preg_match('/^'.preg_quote(self::PREFIX, '/').'([A-Za-z0-9_-]{43})$/', $payload, $m) !== 1) {
            return null;
        }

        $secret = base64_decode(strtr($m[1], '-_', '+/').'=', true);
        if ($secret === false || strlen($secret) !== self::SECRET_BYTES) {
            return null;
        }

        return hash('sha256', $secret);
    }

    private function revokeActive(Actor $actor, Voucher $voucher, string $reason): void
    {
        $active = Medium::query()
            ->where('voucher_id', $voucher->getKey())
            ->where('type', MediumType::PrintableQr->value)
            ->where('status', MediumStatus::Active->value)
            ->get();

        foreach ($active as $medium) {
            /** @var Medium $medium */
            $medium->forceFill([
                'status' => MediumStatus::Revoked,
                'revoked_at' => Carbon::now(),
                'revoked_by' => $actor->userId(),
                'revoke_reason' => $reason,
            ])->save();

            $this->audit->log('medium.revoked', $actor, $medium, ['status' => MediumStatus::Active], ['status' => MediumStatus::Revoked], ['reason' => $reason]);
            $this->events->record(SecurityEventType::MediumRevoke, $actor, subject: $voucher, data: [
                'medium_type' => MediumType::PrintableQr,
                'cause' => $reason,
            ]);
        }
    }
}
