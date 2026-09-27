<?php

declare(strict_types=1);

namespace App\Support;

use App\Models\Device;
use App\Models\User;
use Illuminate\Http\Request;

/**
 * Who performs an operation, from where. Passed into the service layer so that
 * ledger entries and audit logs are attributable even outside HTTP (queues, console).
 */
final readonly class Actor
{
    public function __construct(
        public ?User $user,
        public ?Device $device = null,
        public ?string $ipAddress = null,
        public ?string $userAgent = null,
        public ?string $requestId = null,
    ) {}

    public static function fromRequest(Request $request): self
    {
        /** @var User|null $user */
        $user = $request->user();
        $device = $request->attributes->get('device');

        return new self(
            user: $user,
            device: $device instanceof Device ? $device : null,
            ipAddress: $request->ip(),
            userAgent: mb_substr((string) $request->userAgent(), 0, 500),
            requestId: $request->attributes->get('request_id'),
        );
    }

    public static function system(): self
    {
        return new self(user: null);
    }

    public function userId(): ?string
    {
        return $this->user?->getKey();
    }

    public function deviceId(): ?string
    {
        return $this->device?->getKey();
    }
}
