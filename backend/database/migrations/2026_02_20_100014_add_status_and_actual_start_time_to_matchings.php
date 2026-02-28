<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * 행정관리 정산 기준: status(완료 여부), actual_start_time(앱 타임존 월 필터용).
 * complete = 업무 종료(real_end_time) 처리된 건.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('matchings', function (Blueprint $table): void {
            $table->string('status', 20)->nullable()->after('real_end_time')
                ->comment('scheduled|in_progress|complete. 정산은 complete만 집계');
            $table->dateTime('actual_start_time')->nullable()->after('status')
                ->comment('실제 근무 시작 시각. 앱 타임존 월 기준 필터링용');
        });

        // 기존 완료 건: real_end_time 있으면 complete, actual_start_time = start_at
        if (Schema::hasColumn('matchings', 'real_end_time')) {
            DB::table('matchings')
                ->whereNotNull('real_end_time')
                ->update(['status' => 'complete']);
            DB::statement('UPDATE matchings SET actual_start_time = start_at WHERE real_end_time IS NOT NULL');
        }
    }

    public function down(): void
    {
        Schema::table('matchings', function (Blueprint $table): void {
            $table->dropColumn(['status', 'actual_start_time']);
        });
    }
};
