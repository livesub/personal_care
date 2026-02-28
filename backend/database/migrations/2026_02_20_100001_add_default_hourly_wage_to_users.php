<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 보호사 기본 시급(원). 매칭 등록 시 자동 로드, 매칭별 수정 가능.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedInteger('default_hourly_wage')->default(16150)
                ->after('identity_cancel_count')
                ->comment('보호사 기본 시급(원). 매칭 등록 시 기본값으로 사용.');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE users COMMENT = '보호사 계정 정보 (장애인 제외)'");
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('default_hourly_wage');
        });
    }
};
