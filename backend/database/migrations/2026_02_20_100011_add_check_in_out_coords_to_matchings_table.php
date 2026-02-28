<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 시작/종료 버튼 클릭 시점 좌표만 저장 (실시간 추적 없음). 위치 검증용.
     */
    public function up(): void
    {
        Schema::table('matchings', function (Blueprint $table) {
            $table->decimal('check_in_lat', 10, 8)->nullable()->after('early_stop_reason')->comment('시작 버튼 클릭 시 위도');
            $table->decimal('check_in_lng', 11, 8)->nullable()->after('check_in_lat')->comment('시작 버튼 클릭 시 경도');
            $table->decimal('check_out_lat', 10, 8)->nullable()->after('check_in_lng')->comment('종료 버튼 클릭 시 위도');
            $table->decimal('check_out_lng', 11, 8)->nullable()->after('check_out_lat')->comment('종료 버튼 클릭 시 경도');
        });
    }

    public function down(): void
    {
        Schema::table('matchings', function (Blueprint $table) {
            $table->dropColumn(['check_in_lat', 'check_in_lng', 'check_out_lat', 'check_out_lng']);
        });
    }
};
