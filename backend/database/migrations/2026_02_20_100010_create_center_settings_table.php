<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * 센터별 운영 환경값. 운영 관리(Operations Management) — 바우처 단가 등.
 * 데이터 격리: CenterSetting 모델에서 center_id 기준 Global Scope 적용.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('center_settings', function (Blueprint $table) {
            $table->id()
                ->comment('설정 고유 식별자');
            $table->foreignId('center_id')->constrained('centers')->cascadeOnDelete()
                ->comment('센터 FK. 센터당 1건.');
            $table->decimal('voucher_unit_price', 12, 0)->default(16150)
                ->comment('바우처 시간당 단가(원). 매칭 등록 시 기본값·정산 기준.');
            $table->timestamps();
        });

        $tableName = 'center_settings';
        Schema::table($tableName, function (Blueprint $table) {
            $table->unique('center_id');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE {$tableName} COMMENT = '센터별 운영 설정 (단가 등). center_id 격리'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('center_settings');
    }
};
