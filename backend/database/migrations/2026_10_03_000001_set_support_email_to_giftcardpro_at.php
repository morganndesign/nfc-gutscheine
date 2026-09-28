<?php

declare(strict_types=1);

use App\Models\SystemSetting;
use Illuminate\Database\Migrations\Migration;

/**
 * The support address shown in owner invitations was seeded as the placeholder support@giftcardpro.app.
 * Replace it with support@giftcardpro.at — only while it is still the untouched placeholder, so a value the
 * platform admin entered under System settings is kept.
 */
return new class extends Migration
{
    public function up(): void
    {
        SystemSetting::query()
            ->where('key', 'platform.support_email')
            ->get()
            ->filter(static fn (SystemSetting $s): bool => $s->value === 'support@giftcardpro.app')
            ->each(static fn (SystemSetting $s) => $s->forceFill(['value' => 'support@giftcardpro.at'])->save());
    }

    public function down(): void
    {
        // Irreversible on purpose: the placeholder was never a working address.
    }
};
