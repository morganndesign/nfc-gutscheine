<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Mail\Events\MessageSent;
use Illuminate\Support\Facades\Event;
use Symfony\Component\Mime\Email;
use Tests\TestCase;

/** ops:check-backups: a backup nobody checks is not a backup. */
final class BackupCheckTest extends TestCase
{
    private string $dir;

    private string $keystore;

    /** @var list<Email> */
    private array $sent = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->dir = sys_get_temp_dir().'/gcp-backups-'.bin2hex(random_bytes(4));
        mkdir($this->dir);
        $this->keystore = $this->dir.'-keystore.json';
        file_put_contents($this->keystore, '{"v":1}');
        config([
            'giftcard.backups.dir' => $this->dir,
            'giftcard.backups.offsite_enabled' => true,
            'crypto.local.keystore_path' => $this->keystore,
            'giftcard.ops_alert_email' => 'ops@giftcardpro.test',
            'mail.default' => 'array',
        ]);
        Event::listen(MessageSent::class, function (MessageSent $e): void {
            $this->sent[] = $e->message;
        });
    }

    protected function tearDown(): void
    {
        array_map('unlink', glob($this->dir.'/*') ?: []);
        rmdir($this->dir);
        unlink($this->keystore);
        parent::tearDown();
    }

    private function backup(int $hoursAgo, int $bytes = 50_000, bool $keystore = true): void
    {
        $at = time() - $hoursAgo * 3600;
        $dump = $this->dir.'/giftcard_pro_'.gmdate('Ymd\THis\Z', $at).'.sql.gz';
        file_put_contents($dump, str_repeat('x', $bytes));
        touch($dump, $at);
        if ($keystore) {
            copy($this->keystore, $this->dir.'/keystore_'.gmdate('Ymd\THis\Z', $at).'.json');
        }
        touch($this->dir.'/offsite_success', $at + 3600);
    }

    public function test_a_fresh_complete_backup_that_left_the_server_is_fine(): void
    {
        $this->backup(3);
        $this->artisan('ops:check-backups')->assertSuccessful();
        $this->assertCount(0, $this->sent);
    }

    public function test_a_missing_or_stale_backup_alerts_operations_once(): void
    {
        $this->artisan('ops:check-backups')->expectsOutputToContain('No database backup')->assertFailed();
        $this->backup(30);
        $this->artisan('ops:check-backups')->expectsOutputToContain('No database backup in the last 26 hours')->assertFailed();

        $this->assertCount(1, $this->sent, 'repeats within 12 hours are not mailed again');
        $this->assertSame('ops@giftcardpro.test', $this->sent[0]->getTo()[0]->getAddress());
        $this->assertStringContainsString('Backup problem', (string) $this->sent[0]->getSubject());
    }

    public function test_the_keystore_must_be_backed_up_and_leave_the_server(): void
    {
        $this->backup(2, keystore: false);
        $this->artisan('ops:check-backups')->expectsOutputToContain('card keystore has no backup copy')->assertFailed();

        config(['giftcard.backups.offsite_enabled' => false]);
        $this->backup(1);
        $this->artisan('ops:check-backups')->expectsOutputToContain('Off-site backup is not configured')->assertFailed();
    }

    public function test_an_empty_dump_is_a_problem(): void
    {
        $this->backup(1, bytes: 20);
        $this->artisan('ops:check-backups')->expectsOutputToContain('suspiciously small')->assertFailed();
    }
}
