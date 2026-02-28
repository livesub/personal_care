<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * 보호사 홈: 업무일지, 조기 종료 사유 (기획서 8_AI 보호사 홈.pdf).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('matchings', function (Blueprint $table): void {
            $table->text('work_log')->nullable()->after('actual_start_time')
                ->comment('업무일지');
            $table->text('early_end_reason')->nullable()->after('work_log')
                ->comment('조기 종료 사유');
        });
    }

    public function down(): void
    {
        Schema::table('matchings', function (Blueprint $table): void {
            $table->dropColumn(['work_log', 'early_end_reason']);
        });
    }
};
