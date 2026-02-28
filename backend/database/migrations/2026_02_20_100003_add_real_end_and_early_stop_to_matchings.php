<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 조기 종료 감지: 실제 종료 시각, 조기 종료 사유.
     */
    public function up(): void
    {
        Schema::table('matchings', function (Blueprint $table) {
            $table->dateTime('real_end_time')->nullable()->after('end_at')
                ->comment('실제 종료 시각. 예정보다 빠르면 조기 종료로 표시.');
            $table->text('early_stop_reason')->nullable()->after('real_end_time')
                ->comment('조기 종료 시 보호사가 입력한 사유.');
        });
    }

    public function down(): void
    {
        Schema::table('matchings', function (Blueprint $table) {
            $table->dropColumn(['real_end_time', 'early_stop_reason']);
        });
    }
};
