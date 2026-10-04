<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * A browser that confirmed a sign-in code: no code is asked there until `expires_at` (only the secret's hash is
 * stored; the browser holds it in an encrypted, HTTP-only cookie).
 *
 * @property string $id
 * @property string $user_id
 * @property string $secret_hash
 * @property string|null $user_agent
 * @property Carbon $expires_at
 * @property Carbon|null $last_used_at
 */
class TrustedBrowser extends Model
{
    use HasUuids;

    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'last_used_at' => 'datetime'];
    }
}
