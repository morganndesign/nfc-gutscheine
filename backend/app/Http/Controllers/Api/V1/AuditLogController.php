<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\AuditLogResource;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

final class AuditLogController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $v = $request->validate([
            'action' => ['nullable', 'string', 'max:80'],
            'user_id' => ['nullable', 'uuid'],
            'auditable_id' => ['nullable', 'uuid'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
        ]);

        $logs = AuditLog::query()
            ->with('user')
            ->when($v['action'] ?? null, static fn ($q, $action) => $q->where('action', 'like', addcslashes((string) $action, '%_\\').'%'))
            ->when($v['user_id'] ?? null, static fn ($q, $id) => $q->where('user_id', $id))
            ->when($v['auditable_id'] ?? null, static fn ($q, $id) => $q->where('auditable_id', $id))
            ->when($v['from'] ?? null, fn ($q, $from) => $q->where('created_at', '>=', $this->dayStart((string) $from)))
            ->when($v['to'] ?? null, fn ($q, $to) => $q->where('created_at', '<=', $this->dayEnd((string) $to)))
            ->latest('created_at')
            ->orderByDesc('id')
            ->paginate($this->perPage($request, 50))
            ->withQueryString();

        return AuditLogResource::collection($logs);
    }
}
