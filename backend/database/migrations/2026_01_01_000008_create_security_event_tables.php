<?php

declare(strict_types=1);

use App\Support\Database\AppendOnlyTriggers;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The security event stream (ADR-003): one structured, immutable row for every security-sensitive action,
 * successful or refused. It feeds the risk engine, dashboards, analytics and model training.
 *
 * Rows hold pseudonymous identifiers only (ids, keyed hashes of IP address, user agent and e-mail, the network
 * prefix), never names, e-mail addresses or raw IP addresses. Tamper evidence comes from seals: batches of rows
 * in `seq` order are hash-chained into `security_event_seals` a few minutes after they were written, so writing
 * an event never waits on a shared chain head.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('security_events', function (Blueprint $table): void {
            // Insertion order; seals cover ranges of it.
            $table->id('seq');
            // Public, time-ordered id (ULID).
            $table->char('id', 26)->unique();
            $table->timestamp('occurred_at', 6);
            $table->string('type', 64);
            $table->string('outcome', 16);
            $table->string('reason', 64)->nullable();
            $table->unsignedSmallInteger('schema_version');
            // Plain references without foreign keys, like the audit log: the stream outlives its subjects.
            $table->uuid('restaurant_id')->nullable();
            $table->string('actor_kind', 16);
            $table->uuid('user_id')->nullable();
            $table->uuid('device_id')->nullable();
            $table->string('subject_type', 32)->nullable();
            $table->string('subject_id', 64)->nullable();
            $table->bigInteger('amount')->nullable();
            $table->char('currency', 3)->nullable();
            $table->char('ip_hash', 64)->nullable();
            $table->string('ip_network', 64)->nullable();
            $table->char('user_agent_hash', 64)->nullable();
            $table->string('request_id', 64)->nullable();
            $table->json('data')->nullable();
            $table->index(['type', 'occurred_at']);
            $table->index(['restaurant_id', 'occurred_at']);
            $table->index(['user_id', 'occurred_at']);
            $table->index(['device_id', 'occurred_at']);
            $table->index(['subject_type', 'subject_id']);
            $table->index(['ip_hash', 'occurred_at']);
        });

        Schema::create('security_event_seals', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('from_seq');
            $table->unsignedBigInteger('to_seq')->unique();
            $table->unsignedInteger('event_count');
            $table->char('events_hash', 64);
            $table->char('prev_hash', 64);
            $table->char('seal_hash', 64);
            $table->timestamp('sealed_at', 6);
        });

        AppendOnlyTriggers::create('security_events');
        AppendOnlyTriggers::create('security_event_seals');
    }

    public function down(): void
    {
        AppendOnlyTriggers::drop('security_event_seals');
        AppendOnlyTriggers::drop('security_events');
        Schema::dropIfExists('security_event_seals');
        Schema::dropIfExists('security_events');
    }
};
