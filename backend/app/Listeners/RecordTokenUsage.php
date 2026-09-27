<?php

declare(strict_types=1);

namespace App\Listeners;

use App\Models\PersonalAccessToken;
use App\Services\Auth\DeviceTokenService;
use Illuminate\Support\Facades\Request;
use Laravel\Sanctum\Events\TokenAuthenticated;

/**
 * Stores the IP address an API token was last used from (Sanctum itself only records the time),
 * so owners can spot a leaked POS token being used from an unexpected network, and renews the rolling
 * lifetime of waiter app tokens.
 */
final class RecordTokenUsage
{
    public function __construct(private readonly DeviceTokenService $deviceTokens) {}

    public function handle(TokenAuthenticated $event): void
    {
        $token = $event->token;
        $ip = Request::ip();

        if ($token instanceof PersonalAccessToken && $ip !== null && $token->last_used_ip !== $ip) {
            PersonalAccessToken::query()->whereKey($token->getKey())->update(['last_used_ip' => $ip]);
        }

        if ($token instanceof PersonalAccessToken) {
            $this->deviceTokens->renew($token);
        }
    }
}
