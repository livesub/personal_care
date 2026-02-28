<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 매칭 = 보호사 + 이용자 + 시간대. client_id(이용자), hourly_wage(이 매칭 건 시급) 추가.
     */
    public function up(): void
    {
        Schema::table('matchings', function (Blueprint $table) {
            $table->foreignId('client_id')->nullable()->after('center_id')
                ->constrained('clients')->cascadeOnDelete()
                ->comment('이용자(장애인) ID. 매칭당 1명.');
            $table->unsignedInteger('hourly_wage')->default(16150)->after('end_at')
                ->comment('이 매칭 건 시급(원). 관리자가 매칭별 수정 가능.');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE matchings COMMENT = '보호사-이용자 매칭(스케줄). 전역 중복 체크 대상'");
        }
    }

    public function down(): void
    {
        Schema::table('matchings', function (Blueprint $table) {
            $table->dropForeign(['client_id']);
            $table->dropColumn('hourly_wage');
        });
    }
};
