<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\KeySetStatus;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\KeySet;
use App\Models\User;
use App\Services\Cards\CardBatchLifecycle;
use App\Services\Cards\CardLifecycle;
use App\Support\Actor;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

/** The data migration of 2026-10-03: batches in a removed status land in the status that now covers it. */
final class CardBatchStatusMigrationTest extends TestCase
{
    /** @return Migration&object{mapStatuses: callable} */
    private function migration(): object
    {
        return require database_path('migrations/2026_10_03_000001_simplify_card_batch_lifecycle.php');
    }

    public function test_removed_statuses_are_mapped_and_a_batch_in_qa_can_be_released(): void
    {
        $admin = User::factory()->platformAdmin()->create();
        $other = User::factory()->platformAdmin()->create();
        $actor = new Actor($admin);
        $restaurant = $this->restaurant();
        $keySet = KeySet::query()->create(['version' => 'ks-2026-01', 'manufacturer' => 'Card Co', 'status' => KeySetStatus::Active, 'key_check_values' => []]);
        $batches = app(CardBatchLifecycle::class);
        $cards = app(CardLifecycle::class);

        // As in production: one batch in QA with two QA-passed cards and a first approval already given.
        $inQa = $batches->order($restaurant, $keySet, 'Card Co', 2, $actor);
        $passed = [];
        for ($i = 0; $i < 2; $i++) {
            $card = $cards->transition($cards->register($inQa, "\x04".random_bytes(6), $actor), CardState::Personalized, 'station verified', $actor);
            $passed[] = $cards->transition($card, CardState::QaPassed, 'station verified', $actor);
        }

        DB::table('card_batches')->where('id', $inQa->id)->update(['status' => 'qa_testing', 'accepted_by' => $other->id]);
        $old = ['ordered' => 'in_production', 'personalized' => 'in_production', 'assigned' => 'accepted', 'delivered' => 'shipped', 'in_service' => 'in_service'];
        $ids = [];
        foreach (array_keys($old) as $status) {
            $batch = $batches->order($restaurant, $keySet, 'Card Co', 1, $actor);
            DB::table('card_batches')->where('id', $batch->id)->update(['status' => $status]);
            $ids[$status] = $batch->id;
        }

        // The status mapping of up(); the column drop already ran with the test schema (asserted below).
        $this->migration()->mapStatuses();

        $this->assertFalse(Schema::hasColumn('card_batches', 'accepted_second_by'));
        foreach ($old as $status => $expected) {
            $this->assertSame($expected, DB::table('card_batches')->where('id', $ids[$status])->value('status'), $status);
        }
        $this->assertSame('in_production', DB::table('card_batches')->where('id', $inQa->id)->value('status'));

        $released = $batches->release(CardBatch::query()->withoutGlobalScopes()->findOrFail($inQa->id), $actor);
        $this->assertSame(CardBatchStatus::Accepted, $released->status);
        $this->assertSame($admin->id, $released->accepted_by, 'the release replaces the old first approval');
        foreach ($passed as $card) {
            /** @var Card $card */
            $this->assertSame(CardState::InInventory, $card->refresh()->state);
        }
    }
}
