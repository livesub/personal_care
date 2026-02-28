<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 비상연락처 phone 컬럼 확장 (한글 특이사항 100자 수용).
     * string(20) -> string(255)
     */
    public function up(): void
    {
        $driver = Schema::getConnection()->getDriverName();
        if ($driver === 'mysql') {
            DB::statement('ALTER TABLE client_emergency_contacts MODIFY phone VARCHAR(255) NOT NULL COMMENT \'연락처 전화번호 또는 특이사항 (예: 010-1234-5678 주간 통화 어려움)\'');
        } else {
            Schema::table('client_emergency_contacts', function (Blueprint $table) {
                $table->string('phone', 255)->change();
            });
        }
    }

    public function down(): void
    {
        $driver = Schema::getConnection()->getDriverName();
        if ($driver === 'mysql') {
            DB::statement('ALTER TABLE client_emergency_contacts MODIFY phone VARCHAR(20) NOT NULL COMMENT \'연락처 전화번호 (숫자만 저장 권장)\'');
        } else {
            Schema::table('client_emergency_contacts', function (Blueprint $table) {
                $table->string('phone', 20)->change();
            });
        }
    }
};
