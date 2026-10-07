<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Partner;
use App\Services\Partners\PartnerService;
use Illuminate\Console\Command;

/**
 * POS partners (decision 2026-10-07), run by the platform operator:
 *   partner:manage create "Kassa Wien GmbH" --email=dev@kassa.example   → prints the partner key once
 *   partner:manage list
 *   partner:manage rotate <id>                                          → new key, the old one stops at once
 *   partner:manage suspend <id> | activate <id>
 */
final class ManagePartner extends Command
{
    protected $signature = 'partner:manage {action : create|list|rotate|suspend|activate} {name? : Name (create) or partner id} {--email= : Contact e-mail (create)}';

    protected $description = 'Create and manage POS partners (till systems that redeem vouchers in their own app)';

    public function handle(PartnerService $partners): int
    {
        $action = (string) $this->argument('action');
        $arg = $this->argument('name');

        if ($action === 'list') {
            $this->table(['id', 'name', 'key', 'status', 'connections', 'last used'], Partner::query()->orderBy('name')->get()->map(static fn (Partner $p): array => [
                $p->id, $p->name, $p->key_prefix.'…', $p->status, $p->connections()->where('status', 'active')->count(), $p->last_used_at?->toDateTimeString() ?? '–',
            ])->all());

            return self::SUCCESS;
        }
        if (! is_string($arg) || trim($arg) === '') {
            $this->error('Name (create) or partner id is required.');

            return self::INVALID;
        }
        if ($action === 'create') {
            [$partner, $key] = $partners->create($arg, is_string($this->option('email')) ? $this->option('email') : null);
            $this->info("Partner created: {$partner->name} ({$partner->id})");
            $this->line('Partner key (shown once, give it to the POS company securely):');
            $this->line($key);

            return self::SUCCESS;
        }
        /** @var Partner|null $partner */
        $partner = Partner::query()->find($arg);
        if ($partner === null) {
            $this->error('Unknown partner id.');

            return self::FAILURE;
        }

        return match ($action) {
            'rotate' => $this->rotated($partner, $partners->rotateKey($partner)),
            'suspend', 'activate' => $this->switched($partners, $partner, $action === 'activate'),
            default => $this->invalid($action),
        };
    }

    private function rotated(Partner $partner, string $key): int
    {
        $this->info("New key for {$partner->name} (the old one stops now):");
        $this->line($key);

        return self::SUCCESS;
    }

    private function switched(PartnerService $partners, Partner $partner, bool $active): int
    {
        $partners->setActive($partner, $active);
        $this->info(($active ? 'Active again: ' : 'Suspended: ').$partner->name);

        return self::SUCCESS;
    }

    private function invalid(string $action): int
    {
        $this->error("Unknown action: {$action}");

        return self::INVALID;
    }
}
