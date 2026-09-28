<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
return new class extends Migration {
    public function up(): void {
        Schema::create('audit_drill_partial', function (Blueprint $t) { $t->id(); });   // step 1 succeeds (DDL auto-commits)
        DB::statement('ALTER TABLE gift_cards ADD COLUMN drill_col INT NOT NULL DEFAULT 0'); // step 2 succeeds
        DB::statement('ALTER TABLE gift_cards ADD COLUMN broken_col INT');           // step 3 fails
    }
};
