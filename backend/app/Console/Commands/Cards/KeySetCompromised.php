<?php

declare(strict_types=1);

namespace App\Console\Commands\Cards;

use App\Enums\CardBatchStatus;
use App\Enums\KeySetStatus;
use App\Models\CardBatch;
use App\Models\KeySet;
use App\Services\Cards\CardBatchLifecycle;
use App\Support\Actor;
use App\Support\OpsAlert;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Incident response for a leaked key set (the keystore or a root key was exposed): every batch of the set that can
 * be is declared compromised (stock cards revoked, guests' cards suspended — the owner replaces them), every batch not
 * yet accepted is rejected (its cards fail QA and are never shipped), then the set
 * is retired, so no card of it is verified again — neither a guest tap nor a payment. Irreversible; needs the
 * version typed twice. Afterwards create a new key set (cards:key-set:create) for new batches.
 */
final class KeySetCompromised extends Command
{
    protected $signature = 'cards:key-set:compromised {version} {--confirm= : the version again}';

    protected $description = 'Declare a key set compromised: stop every card of it now and retire the set (irreversible).';

    public function handle(CardBatchLifecycle $batches): int
    {
        $version = (string) $this->argument('version');
        /** @var KeySet|null $set */
        $set = KeySet::query()->where('version', $version)->first();
        if ($set === null || $set->status === KeySetStatus::Retired) {
            $this->error('Unknown or already retired key set.');

            return self::FAILURE;
        }
        if ($this->option('confirm') !== $version) {
            $this->error("Irreversible. Repeat the version: --confirm={$version}");

            return self::FAILURE;
        }

        $actor = Actor::system();
        $declared = DB::transaction(function () use ($set, $batches, $actor): array {
            $declared = [];
            $open = CardBatch::query()->withoutGlobalScopes()->where('key_set_id', $set->getKey())->orderBy('batch_code')->get();
            foreach ($open as $batch) {
                /** @var CardBatch $batch */
                // Released onwards: compromised. Still in production: rejected, its cards never leave.
                $to = $batch->status->canBecome(CardBatchStatus::Compromised) ? CardBatchStatus::Compromised : CardBatchStatus::Rejected;
                if ($batch->status->canBecome($to)) {
                    $batches->changeStatus($batch, $to, "key set {$set->version} compromised", $actor);
                    $declared[] = $batch->batch_code.($to === CardBatchStatus::Rejected ? ' (rejected)' : '');
                }
            }
            $set->forceFill(['status' => KeySetStatus::Retired])->save();

            return $declared;
        });

        $summary = "Key set {$set->version} declared compromised and retired; batches compromised: ".($declared === [] ? 'none' : implode(', ', $declared)).'.';
        OpsAlert::send('key-set-compromised:'.$set->version, 'Key set compromised: '.$set->version, $summary, 60);
        $this->warn($summary);
        $this->line('Next: php artisan cards:key-set:create <new version> — and owners replace their guests\' suspended cards.');

        return self::SUCCESS;
    }
}
