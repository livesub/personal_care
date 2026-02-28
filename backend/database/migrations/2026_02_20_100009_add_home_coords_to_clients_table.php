<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 이용자(장애인) 집 좌표. 위치 검증 시 [버튼 클릭 좌표]와 거리 대조용.
     */
    public function up(): void
    {
        Schema::table('clients', function (Blueprint $table) {
            $table->decimal('home_lat', 10, 8)->nullable()->after('status')->comment('이용자 집 위도');
            $table->decimal('home_lng', 11, 8)->nullable()->after('home_lat')->comment('이용자 집 경도');
        });
    }

    public function down(): void
    {
        Schema::table('clients', function (Blueprint $table) {
            $table->dropColumn(['home_lat', 'home_lng']);
        });
    }
};
