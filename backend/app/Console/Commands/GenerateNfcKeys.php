<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;

final class GenerateNfcKeys extends Command
{
    protected $signature = 'giftcard:nfc-keys';

    protected $description = 'Generate random AES-128 keys for NTAG 424 DNA secure messaging (SUN).';

    public function handle(): int
    {
        $this->line('Add these lines to your .env (keep them secret and backed up — tags programmed with them cannot be verified without them):');
        $this->newLine();
        $this->line('NTAG424_META_READ_KEY='.strtoupper(bin2hex(random_bytes(16))));
        $this->line('NTAG424_FILE_READ_KEY='.strtoupper(bin2hex(random_bytes(16))));

        return self::SUCCESS;
    }
}
