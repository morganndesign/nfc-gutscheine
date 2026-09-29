<?php

declare(strict_types=1);

use App\Support\Database\AppendOnlyTriggers;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Physical cards (architecture §7–§9): key sets (metadata only, never key material), batches (one batch = one
 * restaurant order = one shipment), cards with one stored lifecycle state, and the append-only, hash-chained
 * card event history. Media of type nfc_card point at their card.
 */
return new class extends Migration
{
    /** @var list<string> */
    public const CARD_STATES = [
        'manufactured', 'personalized', 'qa_passed', 'qa_failed', 'in_inventory', 'assigned', 'shipped', 'delivered',
        'available', 'bound', 'active', 'suspended', 'replaced', 'revoked', 'lost', 'destroyed',
    ];

    public function up(): void
    {
        Schema::create('key_sets', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            // The key-set version in every tap URL of its cards ({k}) and the prefix of its key references.
            $table->string('version', 32)->unique();
            $table->string('manufacturer', 120);
            // active: new batches; verify_only: cards still in use, no new batches; retired: no card left.
            $table->string('status', 16);
            // Key check values of the roots, recorded at the ceremony and compared with the provider.
            $table->json('key_check_values');
            $table->timestamps();
        });

        Schema::create('card_batches', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('batch_code', 20)->unique();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('key_set_id')->constrained()->restrictOnDelete();
            $table->string('manufacturer', 120);
            $table->string('chip_type', 20);
            $table->string('card_design_ref', 120)->nullable();
            $table->unsignedInteger('quantity_ordered');
            $table->string('personalization', 20);
            $table->string('status', 20);
            $table->date('production_date')->nullable();
            foreach (['ordered', 'personalized', 'accepted', 'shipped', 'delivered', 'received'] as $moment) {
                $table->timestamp($moment.'_at')->nullable();
            }
            $table->foreignUuid('accepted_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->foreignUuid('accepted_second_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->foreignUuid('received_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->string('tracking_ref', 120)->nullable();
            $table->char('manifest_sha256', 64)->nullable();
            $table->json('qa_report')->nullable();
            $table->timestamps();

            $table->index(['restaurant_id', 'status']);
        });

        Schema::create('cards', function (Blueprint $table): void {
            // UUID version 4, never serialised to any client.
            $table->uuid('id')->primary();
            // Inventory number <batch code>-<sequence>, for staff and platform support.
            $table->string('card_number', 32)->unique();
            // The chip UID, used only inside verification.
            $table->binary('uid', 7, fixed: true)->unique();
            $table->string('chip_type', 20);
            $table->foreignUuid('batch_id')->constrained('card_batches')->restrictOnDelete();
            $table->foreignUuid('key_set_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('restaurant_id')->constrained()->restrictOnDelete();
            $table->string('state', 20);
            $table->timestamp('state_changed_at', 6);
            // Highest SDM read counter accepted (compare-and-set on every verified tap).
            $table->unsignedInteger('sdm_counter')->nullable();
            $table->string('originality_signature', 128)->nullable();
            $table->foreignUuid('successor_card_id')->nullable()->constrained('cards')->restrictOnDelete();
            $table->timestamps();

            $table->index(['batch_id', 'state']);
            $table->index(['restaurant_id', 'state']);
        });

        Schema::create('card_events', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            // Plain references, like the audit log: the history outlives what it describes.
            $table->uuid('card_id');
            $table->uuid('batch_id');
            $table->uuid('restaurant_id')->nullable();
            $table->string('from_state', 20)->nullable();
            $table->string('to_state', 20);
            $table->string('reason', 120);
            $table->uuid('actor_id')->nullable();
            $table->uuid('device_id')->nullable();
            $table->string('request_id', 64)->nullable();
            $table->string('ref_type', 40)->nullable();
            $table->string('ref_id', 64)->nullable();
            $table->timestamp('created_at', 6)->useCurrent();
            $table->string('chain_scope', 36);
            $table->unsignedBigInteger('chain_seq');
            $table->char('prev_hash', 64);
            $table->char('entry_hash', 64);
            $table->unique(['chain_scope', 'chain_seq']);
            $table->index(['card_id', 'created_at']);
        });

        Schema::table('media', function (Blueprint $table): void {
            $table->foreignUuid('card_id')->nullable()->unique()->after('status')->constrained('cards')->restrictOnDelete();
        });

        // A live-authenticated card presentment records the card, the UID the phone saw on the radio layer and the
        // SUN counter of the tap.
        Schema::table('presentments', function (Blueprint $table): void {
            $table->foreignUuid('card_id')->nullable()->after('medium_id')->constrained('cards')->restrictOnDelete();
            $table->binary('rf_uid', 7, fixed: true)->nullable()->after('card_id');
            $table->unsignedInteger('sdm_counter')->nullable()->after('rf_uid');
        });

        $states = "'".implode("','", self::CARD_STATES)."'";
        if (in_array(DB::connection()->getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE cards ADD CONSTRAINT cards_state_check CHECK (state IN ({$states}))");
        } else {
            // SQLite cannot add a CHECK to an existing table; triggers enforce the same rule.
            foreach (['INSERT', 'UPDATE'] as $operation) {
                DB::unprepared('CREATE TRIGGER cards_state_check_'.strtolower($operation)." BEFORE {$operation} ON cards FOR EACH ROW "
                    ."WHEN NEW.state NOT IN ({$states}) BEGIN SELECT RAISE(ABORT, 'cards.state is not a card state'); END");
            }
        }

        AppendOnlyTriggers::create('card_events');
    }

    public function down(): void
    {
        AppendOnlyTriggers::drop('card_events');
        Schema::table('presentments', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('card_id');
            $table->dropColumn(['rf_uid', 'sdm_counter']);
        });
        Schema::table('media', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('card_id');
        });
        Schema::dropIfExists('card_events');
        Schema::dropIfExists('cards');
        Schema::dropIfExists('card_batches');
        Schema::dropIfExists('key_sets');
    }
};
