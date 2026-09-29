<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\SystemSetting;
use App\Services\Integrity\ChainVerifier;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

final class VerifyChains extends Command
{
    protected $signature = 'giftcard:verify-chains';

    protected $description = 'Recompute the hash chains of ledger, payments and audit log, and every voucher balance.';

    public function handle(ChainVerifier $verifier): int
    {
        $problems = $verifier->verify();

        if ($problems === []) {
            $this->info('All hash chains and voucher balances are intact.');

            return self::SUCCESS;
        }

        foreach ($problems as $problem) {
            $this->error($problem);
        }

        Log::critical('Integrity check failed: financial history or audit log does not verify', [
            'problems' => count($problems),
            'first' => array_slice($problems, 0, 20),
        ]);
        $this->notifyOperations($problems);

        return self::FAILURE;
    }

    /** @param list<string> $problems */
    private function notifyOperations(array $problems): void
    {
        $to = config('giftcard.ops_alert_email') ?: SystemSetting::get('platform.support_email');
        if (! is_string($to) || $to === '') {
            return;
        }

        try {
            Mail::raw(
                'The nightly integrity check found '.count($problems)." problem(s) in the ledger, payments or audit log:\n\n"
                .implode("\n", array_slice($problems, 0, 50))
                ."\n\nTreat this as a security incident: preserve the database and the backups before changing anything.",
                static fn ($message) => $message->to($to)->subject('[GiftCard Pro] Integrity check failed'),
            );
        } catch (Throwable $e) {
            Log::error('Integrity alert could not be sent', ['error' => $e->getMessage()]);
        }
    }
}
