<?php

declare(strict_types=1);

namespace App\Services\Online;

use App\Enums\RoleSlug;
use App\Enums\UserStatus;
use App\Models\User;
use App\Notifications\OnlinePaymentNotification;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/** E-mails the owners of a restaurant about an online payment, in their language, after the change is committed. */
final class OnlinePaymentMails
{
    /** @param 'dispute'|'refunded_elsewhere' $kind */
    public function owners(string $restaurantId, string $restaurantName, string $kind, string $voucherNumber, int $amount, string $currency): void
    {
        DB::afterCommit(static function () use ($restaurantId, $restaurantName, $kind, $voucherNumber, $amount, $currency): void {
            $owners = User::query()
                ->where('restaurant_id', $restaurantId)
                ->where('status', UserStatus::Active->value)
                ->whereHas('role', static fn ($r) => $r->where('slug', RoleSlug::Owner->value))
                ->get();
            foreach ($owners as $user) {
                /** @var User $user */
                $language = in_array($user->locale, ['de', 'en', 'bs'], true) ? $user->locale : (string) config('giftcard.mail_locale');
                try {
                    $user->notify((new OnlinePaymentNotification($kind, $restaurantName, $voucherNumber, $amount, $currency))->locale($language));
                } catch (Throwable $e) {
                    Log::warning('Online payment notice could not be e-mailed.', ['user_id' => $user->getKey(), 'kind' => $kind, 'error' => $e->getMessage()]);
                }
            }
        });
    }
}
