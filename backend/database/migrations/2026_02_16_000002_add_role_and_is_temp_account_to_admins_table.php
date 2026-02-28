<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * admins 테이블에 role, is_temp_account 컬럼 추가.
 * 명세: super/staff 역할, 임시 계정 여부.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admins', function (Blueprint $table) {
            $table->enum('role', ['super', 'staff'])->default('staff')->after('email')
                ->comment('super: 전체 권한, staff: 정산 제외');
            $table->boolean('is_temp_account')->default(true)->after('role')
                ->comment('1: 임시 계정(최초 로그인 시 비밀번호 변경 유도), 0: 정식 계정');
        });

        // login_id, password 컬럼 설명은 모델 Mutator로 소문자 변환 적용됨.
    }

    public function down(): void
    {
        Schema::table('admins', function (Blueprint $table) {
            $table->dropColumn(['role', 'is_temp_account']);
        });
    }
};
