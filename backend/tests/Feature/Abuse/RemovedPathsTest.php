<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\RoleSlug;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * Architecture §15 and ADR-002: paths that could spend or bind without cryptographic proof do not exist.
 */
final class RemovedPathsTest extends TestCase
{
    public function test_removed_endpoints_do_not_exist(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $id = $voucher->id;

        $removed = [
            ['POST', '/api/v1/scan'],
            ['GET', "/api/v1/public/cards/{$id}"],
            ['POST', '/api/v1/cards'],
            ['POST', "/api/v1/cards/{$id}/redeem"],
            ['POST', "/api/v1/cards/{$id}/reload"],
            ['POST', "/api/v1/cards/{$id}/transfer"],
            ['POST', "/api/v1/cards/{$id}/replace"],
            ['POST', "/api/v1/cards/{$id}/activate"],
            ['GET', "/api/v1/cards/{$id}/nfc"],
            ['POST', "/api/v1/cards/{$id}/nfc"],
            ['POST', "/api/v1/cards/{$id}/nfc/check"],
            ['POST', "/api/v1/cards/{$id}/nfc/lock"],
            ['GET', "/api/v1/cards/{$id}/qr"],
            ['POST', "/api/v1/vouchers/{$id}/redeem"],
            ['POST', "/api/v1/vouchers/{$id}/transfer"],
            ['POST', "/api/v1/vouchers/{$id}/replace"],
            ['POST', "/api/v1/vouchers/{$id}/activate"],
            ['GET', "/api/v1/vouchers/{$id}/qr"],
        ];

        foreach ($removed as [$method, $uri]) {
            $status = $this->withHeaders($this->idempotency())->json($method, $uri, ['amount' => 100])->status();
            $this->assertContains($status, [404, 405], "{$method} {$uri} must not exist (got {$status}).");
        }
    }

    public function test_every_debit_route_requires_a_presentment(): void
    {
        $debits = collect(Route::getRoutes()->getRoutes())
            ->filter(static fn ($route): bool => in_array('POST', $route->methods(), true) && str_contains($route->uri(), 'redemption'))
            ->map(static fn ($route): string => $route->uri())
            ->values()
            ->all();

        $this->assertSame(['api/v1/vouchers/{voucher}/redemptions'], $debits);
    }

    /** P0-01: no reference to the removed flows remains in the application code. */
    public function test_no_legacy_code_remains(): void
    {
        $forbidden = ['public_token', 'ntag21', 'Ntag213', 'Ntag215', 'Ntag216', 'nfc_uid', 'write_nfc', 'NfcProgramming', 'CardScan', 'transfer_in', 'transfer_out', 'replaced_by', 'replaces_id', "'/scan'", 'card_base_url'];
        $offenders = [];

        foreach (['app', 'routes', 'config', 'database'] as $dir) {
            $files = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator(base_path($dir), \FilesystemIterator::SKIP_DOTS));
            foreach ($files as $file) {
                /** @var \SplFileInfo $file */
                if ($file->getExtension() !== 'php') {
                    continue;
                }
                $content = (string) file_get_contents($file->getPathname());
                foreach ($forbidden as $needle) {
                    if (stripos($content, $needle) !== false) {
                        $offenders[] = str_replace(base_path().'/', '', $file->getPathname()).': '.$needle;
                    }
                }
            }
        }

        $this->assertSame([], $offenders);
    }
}
