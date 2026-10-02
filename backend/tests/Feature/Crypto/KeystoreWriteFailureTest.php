<?php

declare(strict_types=1);

namespace Tests\Feature\Crypto;

use App\Crypto\Exceptions\KeystoreException;
use App\Crypto\KeyReference;
use App\Crypto\Local\LocalKeystore;
use Tests\TestCase;

/**
 * A keystore write that fails (full disk, rename refused) inside the application, where PHP warnings are exceptions:
 * the old keystore stays as it was and no temporary copy of it is left next to it.
 */
final class KeystoreWriteFailureTest extends TestCase
{
    private string $directory;

    protected function setUp(): void
    {
        parent::setUp();
        $this->directory = sys_get_temp_dir().'/gcp-ks-fail-'.bin2hex(random_bytes(6));
        mkdir($this->directory);
    }

    protected function tearDown(): void
    {
        foreach ((array) glob($this->directory.'/{,.}*', GLOB_BRACE) as $entry) {
            if (is_string($entry) && ! in_array(basename($entry), ['.', '..'], true)) {
                is_dir($entry) ? rmdir($entry) : unlink($entry);
            }
        }
        rmdir($this->directory);
        parent::tearDown();
    }

    public function test_a_failed_write_leaves_no_temporary_keystore_behind(): void
    {
        // The rename onto the target fails: the target is a directory.
        $target = $this->directory.'/keystore.json';
        mkdir($target);

        try {
            (new LocalKeystore($target, random_bytes(32)))->create();
            $this->fail('The write must fail.');
        } catch (KeystoreException $e) {
            $this->assertStringContainsString('cannot be written', $e->getMessage());
        }

        $this->assertSame([], glob($this->directory.'/*.tmp'), 'no temporary keystore is left behind');
        $this->assertDirectoryExists($target);
    }

    public function test_a_written_keystore_is_owner_only_and_replaces_the_old_one_whole(): void
    {
        $path = $this->directory.'/keystore.json';
        $keystore = new LocalKeystore($path, random_bytes(32));
        $keystore->create();
        $before = (string) file_get_contents($path);
        $keystore->add(new KeyReference('ks-1/root-k0'), random_bytes(16));

        $this->assertNotSame($before, (string) file_get_contents($path));
        $this->assertCount(1, $keystore->read());
        $this->assertSame('0600', substr(sprintf('%o', fileperms($path)), -4));
        $this->assertSame([], glob($this->directory.'/*.tmp'));
    }
}
