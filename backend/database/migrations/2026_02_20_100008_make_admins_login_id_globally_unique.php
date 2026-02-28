<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * admins.login_id를 전역 유일(unique)로 변경.
 * - 복합 unique (center_id, login_id) 제거 → 로그인 시 센터별 중복 아이디로 인한 충돌 방지.
 * - login_id 단일 컬럼 unique 추가로 DB 수준에서 중복 차단.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admins', function (Blueprint $table): void {
            $table->dropUnique(['center_id', 'login_id']);
        });
        Schema::table('admins', function (Blueprint $table): void {
            $table->unique('login_id');
        });
    }

    public function down(): void
    {
        Schema::table('admins', function (Blueprint $table): void {
            $table->dropUnique(['login_id']);
        });
        Schema::table('admins', function (Blueprint $table): void {
            $table->unique(['center_id', 'login_id']);
        });
    }
};
