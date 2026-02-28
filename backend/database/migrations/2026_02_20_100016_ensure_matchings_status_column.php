<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * matchings 테이블에 status 컬럼이 없을 경우 추가 (기본값 'scheduled').
 * 기존 레코드는 status = 'scheduled'로 업데이트.
 */
return new class extends Migration
{
    public function up(): void
    {
        $table = 'matchings';
        if (! Schema::hasColumn($table, 'status')) {
            Schema::table($table, function (Blueprint $table): void {
                $table->string('status', 20)->default('scheduled')
                    ->comment('scheduled|start|complete');
            });
        }

        DB::table($table)->whereNull('status')->update(['status' => 'scheduled']);
    }

    public function down(): void
    {
        if (Schema::hasColumn('matchings', 'status')) {
            Schema::table('matchings', function (Blueprint $table): void {
                $table->dropColumn('status');
            });
        }
    }
};
