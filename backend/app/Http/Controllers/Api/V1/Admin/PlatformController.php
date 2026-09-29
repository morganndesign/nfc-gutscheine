<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\RestaurantStatus;
use App\Enums\TransactionType;
use App\Enums\VoucherStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\UpdateSystemSettingsRequest;
use App\Http\Resources\AuditLogResource;
use App\Models\AuditLog;
use App\Models\Restaurant;
use App\Models\SystemSetting;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Audit\AuditLogger;
use App\Services\Users\InvitationService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Throwable;

final class PlatformController extends Controller
{
    public function stats(): JsonResponse
    {
        $monthStart = Carbon::now()->startOfMonth();

        return response()->json(['data' => [
            'restaurants_total' => Restaurant::query()->count(),
            'restaurants_active' => Restaurant::query()->where('status', RestaurantStatus::Active->value)->count(),
            'restaurants_archived' => Restaurant::onlyTrashed()->count(),
            'vouchers_total' => Voucher::query()->withoutGlobalScopes()->count(),
            'vouchers_active' => Voucher::query()->withoutGlobalScopes()->where('status', VoucherStatus::Active->value)->count(),
            'transactions_this_month' => VoucherTransaction::query()->withoutGlobalScopes()->where('created_at', '>=', $monthStart)->count(),
            'volume_sold_this_month' => (int) VoucherTransaction::query()->withoutGlobalScopes()
                ->whereIn('type', [TransactionType::Issue->value, TransactionType::Reload->value])
                ->whereDoesntHave('reversal')
                ->where('created_at', '>=', $monthStart)
                ->sum('amount'),
        ]]);
    }

    public function auditLogs(Request $request): AnonymousResourceCollection
    {
        $v = $request->validate([
            'restaurant_id' => ['nullable', 'uuid'],
            'action' => ['nullable', 'string', 'max:80'],
        ]);

        $logs = AuditLog::query()
            ->withoutGlobalScopes()
            ->with(['user', 'restaurant'])
            ->when($v['restaurant_id'] ?? null, static fn ($q, $id) => $q->where('restaurant_id', $id))
            ->when($v['action'] ?? null, static fn ($q, $a) => $q->where('action', 'like', addcslashes((string) $a, '%_\\').'%'))
            ->latest('created_at')
            ->orderByDesc('id')
            ->paginate($this->perPage($request, 50))
            ->withQueryString();

        return AuditLogResource::collection($logs);
    }

    public function settings(): JsonResponse
    {
        return response()->json(['data' => SystemSetting::query()->orderBy('key')->get(['key', 'value', 'type', 'description', 'is_public'])]);
    }

    public function updateSettings(UpdateSystemSettingsRequest $request, AuditLogger $audit): JsonResponse
    {
        DB::transaction(function () use ($request, $audit): void {
            /** @var list<array{key: string, value: mixed}> $items */
            $items = $request->validated('settings');
            foreach ($items as $item) {
                /** @var SystemSetting $setting */
                $setting = SystemSetting::query()->where('key', $item['key'])->firstOrFail();
                $old = $setting->value;
                $setting->value = $this->cast($setting->type, $item['value']);
                if ($setting->isDirty('value')) {
                    $setting->save();
                    $audit->log('system_setting.updated', Actor::fromRequest($request), $setting, ['value' => $old], ['value' => $setting->value], restaurantId: null);
                }
            }
        });

        return $this->settings();
    }

    /** Whether e-mails (invitations, password links, card e-mails) actually reach recipients. */
    public function mailStatus(InvitationService $invitations): JsonResponse
    {
        $delivers = $invitations->mailDelivers();

        return response()->json(['data' => [
            'mailer' => (string) config('mail.default'),
            'delivers' => $delivers,
            'from_address' => config('mail.from.address'),
            'from_name' => config('mail.from.name'),
            // Where SMTP connects (no credentials), so the admin can confirm the production settings.
            'host' => config('mail.default') === 'smtp' ? config('mail.mailers.smtp.host') : null,
            'port' => config('mail.default') === 'smtp' ? (int) config('mail.mailers.smtp.port') : null,
            'problem' => $delivers ? null : $invitations->nonDeliveryReason(),
        ]]);
    }

    /**
     * Sends a short test e-mail and reports the mail server's answer. Recipient: the signed-in platform
     * administrator (session guard "web" via Sanctum for the dashboard, or a Sanctum token), or an explicit
     * `to` address. The recipient is validated and logged before anything is sent.
     */
    public function sendTestMail(Request $request, InvitationService $invitations, AuditLogger $audit): JsonResponse
    {
        $user = $this->user($request);
        $to = $request->validate(['to' => ['nullable', 'string', 'max:191']])['to'] ?? null;
        $recipient = Str::lower(trim((string) ($to ?? $user->email)));
        $guard = Auth::guard('web')->check() ? 'web (session via Sanctum)' : 'sanctum (API token)';

        Log::info('Platform test e-mail requested', [
            'recipient' => $recipient,
            'recipient_source' => $to !== null ? 'request' : 'authenticated user',
            'user_id' => $user->getKey(),
            'user_email' => $user->email,
            'guard' => $guard,
            'mailer' => config('mail.default'),
        ]);

        $rules = ['required', 'email:rfc'];
        if (config('giftcard.verify_mail_domains')) {
            $rules = ['required', 'email:rfc,dns'];
        }
        Validator::make(['to' => $recipient], ['to' => $rules], [
            'to.required' => 'Your account has no e-mail address. Enter a recipient for the test e-mail.',
            'to.email' => "\"{$recipient}\" cannot receive e-mail: the address is invalid or its domain has no mail server (MX record).",
        ])->validate();

        if (! $invitations->mailDelivers()) {
            return response()->json(['message' => $invitations->nonDeliveryReason(), 'code' => 'MAIL_NOT_DELIVERED'], 422);
        }

        $data = ['recipient' => $recipient, 'mailer' => (string) config('mail.default'), 'guard' => $guard];

        try {
            Mail::raw(
                "This is a test e-mail from GiftCard Pro.\n\nIf you can read it, invitations and password e-mails are delivered.",
                static fn ($m) => $m->to($recipient)->subject('GiftCard Pro: test e-mail'),
            );
        } catch (Throwable $e) {
            report($e);
            $error = mb_substr($e->getMessage(), 0, 500);
            // 550–553: the server accepted the connection and the sender but refused this recipient.
            $rejected = (bool) preg_match('/\b55[0-3]\b/', $error);
            $audit->log('platform.mail_test', Actor::fromRequest($request), null, metadata: ['result' => 'failed', 'recipient' => $recipient], restaurantId: null);

            return response()->json([
                'message' => $rejected
                    ? "The mail server refused the recipient {$recipient}: {$error} The connection, login and sender work; this address (or its domain) cannot receive e-mail. Test with another address."
                    : "The mail server refused the test e-mail to {$recipient}: {$error}",
                'code' => $rejected ? 'MAIL_RECIPIENT_REJECTED' : 'MAIL_NOT_DELIVERED',
                'data' => $data,
            ], 422);
        }

        $audit->log('platform.mail_test', Actor::fromRequest($request), null, metadata: ['result' => 'sent', 'recipient' => $recipient], restaurantId: null);

        return response()->json(['message' => "Test e-mail sent to {$recipient}.", 'data' => $data]);
    }

    private function cast(string $type, mixed $value): mixed
    {
        return match ($type) {
            'boolean' => filter_var($value, FILTER_VALIDATE_BOOLEAN),
            'integer' => (int) $value,
            'string' => $value === null ? null : mb_substr((string) $value, 0, 2000),
            default => $value,
        };
    }
}
