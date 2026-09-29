<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\SecurityAlert;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Carbon;

/** Fraud and attack alerts for the platform: newest first, open ones on top; acknowledged with a note. */
final class SecurityAlertController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $status = $request->query('status');
        $severity = $request->query('severity');
        $page = SecurityAlert::query()
            ->when(in_array($status, ['open', 'acknowledged'], true), static fn ($q) => $q->where('status', $status))
            ->when(in_array($severity, ['warning', 'high', 'critical'], true), static fn ($q) => $q->where('severity', $severity))
            ->orderByRaw("CASE status WHEN 'open' THEN 0 ELSE 1 END")
            ->orderByDesc('last_seen_at')
            ->paginate($this->perPage($request, 50));

        return JsonResource::collection($page->through(static fn (SecurityAlert $a): array => self::present($a)));
    }

    public function acknowledge(Request $request, AuditLogger $audit, string $alert): JsonResponse
    {
        $note = $request->validate(['note' => ['required', 'string', 'min:3', 'max:500']])['note'];
        /** @var SecurityAlert $found */
        $found = SecurityAlert::query()->findOrFail($alert);
        if ($found->status === 'open') {
            $found->forceFill(['status' => 'acknowledged', 'acknowledged_by' => $request->user()?->getAuthIdentifier(), 'acknowledged_at' => Carbon::now(), 'note' => $note])->save();
            $audit->log('security_alert.acknowledged', Actor::fromRequest($request), $found, null, ['rule' => $found->rule, 'note' => $note]);
        }

        return response()->json(['data' => self::present($found)]);
    }

    /** @return array<string, mixed> */
    private static function present(SecurityAlert $a): array
    {
        return [
            'id' => $a->id,
            'rule' => $a->rule,
            'severity' => $a->severity,
            'restaurant_id' => $a->restaurant_id,
            'subject' => $a->subject,
            'occurrences' => $a->occurrences,
            'first_event_seq' => $a->first_event_seq,
            'last_event_seq' => $a->last_event_seq,
            'first_seen_at' => $a->first_seen_at->toIso8601String(),
            'last_seen_at' => $a->last_seen_at->toIso8601String(),
            'status' => $a->status,
            'acknowledged_at' => $a->acknowledged_at?->toIso8601String(),
            'note' => $a->note,
        ];
    }
}
