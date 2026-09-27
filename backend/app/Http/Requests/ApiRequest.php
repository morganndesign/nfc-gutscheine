<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Support\Tenancy\TenantContext;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Exists;

/**
 * Base request. Authorization is enforced by route middleware / controllers (permission gates),
 * so requests only validate input.
 */
abstract class ApiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function tenantId(): ?string
    {
        return app(TenantContext::class)->id();
    }

    /** exists-rule constrained to the current restaurant and non-deleted rows. */
    protected function existsInTenant(string $table, string $column = 'id'): Exists
    {
        return Rule::exists($table, $column)
            ->where('restaurant_id', $this->tenantId())
            ->whereNull('deleted_at');
    }
}
