<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Support\OpsAlert;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

/**
 * Hourly: the database backup and the card keystore copy of the last day exist and are complete, and — when an
 * off-site target is configured — they left the server. Anything else is an operations alert (twice a day at
 * most). A backup nobody checks is not a backup.
 */
final class CheckBackups extends Command
{
    private const MAX_AGE_HOURS = 26;

    protected $signature = 'ops:check-backups';

    protected $description = 'Alert operations when the last database backup, keystore copy or off-site copy is missing or too old.';

    public function handle(): int
    {
        $dir = (string) config('giftcard.backups.dir');
        if ($dir === '' || ! is_dir($dir)) {
            $this->warn('No backup directory is mounted here.');

            return self::SUCCESS;
        }

        $problems = [];
        $dumps = glob($dir.'/giftcard_pro_*.sql.gz') ?: [];
        $newest = $this->newest($dumps);
        if ($newest === null || filemtime($newest) < Carbon::now()->subHours(self::MAX_AGE_HOURS)->getTimestamp()) {
            $problems[] = 'No database backup in the last '.self::MAX_AGE_HOURS.' hours'.($newest !== null ? ' (newest: '.basename($newest).')' : '').'.';
        } elseif ((int) filesize($newest) < 1024) {
            $problems[] = 'The newest database backup '.basename($newest).' is suspiciously small ('.filesize($newest).' bytes).';
        }

        $keystore = (string) config('crypto.local.keystore_path');
        $copies = glob($dir.'/keystore_*.json') ?: [];
        if (is_file($keystore) && ($copy = $this->newest($copies)) === null) {
            $problems[] = 'The card keystore has no backup copy: without it no card can be verified after a server loss.';
        } elseif (is_file($keystore) && isset($copy) && hash_file('sha256', $copy) !== hash_file('sha256', $keystore)) {
            // A new key set since the last backup: the copy is from before it (the next backup takes it).
            if (filemtime($keystore) < Carbon::now()->subHours(self::MAX_AGE_HOURS)->getTimestamp()) {
                $problems[] = 'The newest keystore copy differs from the keystore in use.';
            }
        }

        if (config('giftcard.backups.offsite_enabled')) {
            $marker = $dir.'/offsite_success';
            if (! is_file($marker) || filemtime($marker) < Carbon::now()->subHours(self::MAX_AGE_HOURS)->getTimestamp()) {
                $problems[] = 'No off-site copy of the backups in the last '.self::MAX_AGE_HOURS.' hours (check the "offsite" service).';
            }
        } else {
            $problems[] = 'Off-site backup is not configured: a lost server would lose every voucher and every card key. Set OFFSITE_SFTP_* (see docs/DEPLOYMENT.md).';
        }

        if ($problems === []) {
            $this->info('Backups are current'.(config('giftcard.backups.offsite_enabled') ? ' and off-site.' : '.'));

            return self::SUCCESS;
        }

        foreach ($problems as $problem) {
            $this->error($problem);
        }
        OpsAlert::send('backups', 'Backup problem', implode("\n", $problems)."\n\nSee docs/de/06-technical/backup-guide.md.");

        return self::FAILURE;
    }

    /** @param list<string> $files */
    private function newest(array $files): ?string
    {
        usort($files, static fn (string $a, string $b): int => filemtime($b) <=> filemtime($a));

        return $files[0] ?? null;
    }
}
