<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

/**
 * Tables that grow with every voucher action or e-mail must answer the dashboard's list queries from an index, not
 * by sorting the whole table on every page load.
 */
final class HotQueryIndexTest extends TestCase
{
    /** @return list<list<string>> */
    private function indexedColumns(string $table): array
    {
        return array_map(static fn (array $index): array => $index['columns'], Schema::getIndexes($table));
    }

    public function test_the_platform_audit_log_newest_first_is_read_from_an_index(): void
    {
        // GET /admin/audit-logs without a restaurant filter: ORDER BY created_at DESC, id DESC LIMIT 50.
        $this->assertContains(['created_at'], $this->indexedColumns('audit_logs'));
    }

    public function test_the_invitation_state_of_staff_is_read_from_an_index(): void
    {
        // Staff and restaurant lists: the last invitation e-mail per address (InvitationService::summaries()).
        $this->assertContains(['recipient', 'template_key'], $this->indexedColumns('notification_logs'));
    }
}
