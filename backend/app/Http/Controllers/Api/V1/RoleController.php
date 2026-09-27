<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class RoleController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $this->user($request);

        $roles = Role::query()
            ->where('scope', 'restaurant')
            ->orderByDesc('rank')
            ->get()
            ->map(static fn (Role $role): array => [
                'slug' => $role->slug->value,
                'name' => $role->name,
                'description' => $role->description,
                'permissions' => $role->permissionSlugs(),
                'assignable' => $user->isPlatformAdmin() || $user->canManageRole($role),
            ]);

        return response()->json(['data' => $roles]);
    }
}
