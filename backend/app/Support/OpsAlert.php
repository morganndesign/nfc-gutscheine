<?php

declare(strict_types=1);

namespace App\Support;

use App\Models\SystemSetting;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * An e-mail to operations (OPS_ALERT_EMAIL, else the platform support address), logged as critical and sent at
 * most once per `$key` within `$repeatAfterSeconds`, so a long outage does not flood the inbox.
 */
final class OpsAlert
{
    public static function send(string $key, string $subject, string $body, int $repeatAfterSeconds = 43200): bool
    {
        Log::critical($subject, ['alert' => $key]);
        if (! Cache::add('ops-alert:'.$key, true, $repeatAfterSeconds)) {
            return false;
        }
        $to = config('giftcard.ops_alert_email') ?: SystemSetting::get('platform.support_email');
        if (! is_string($to) || $to === '') {
            // Nobody could be told: try again next time instead of staying silent for the whole window.
            Cache::forget('ops-alert:'.$key);

            return false;
        }
        try {
            Mail::raw($body, static fn ($message) => $message->to($to)->subject('[GiftCard Pro] '.$subject));

            return true;
        } catch (Throwable $e) {
            Log::error('Operations alert could not be sent', ['alert' => $key, 'error' => $e->getMessage()]);
            Cache::forget('ops-alert:'.$key);

            return false;
        }
    }
}
