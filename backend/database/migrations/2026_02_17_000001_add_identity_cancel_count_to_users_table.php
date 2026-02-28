<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 계정 잠금용: 본인 확인 3회 연속 취소 시 잠금 판단에 사용.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedInteger('identity_cancel_count')->default(0)->after('is_first_login')
                ->comment('본인 확인 팝업 연속 취소 횟수. 3회 시 계정 잠금.');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE users COMMENT = '보호사 계정 정보 (장애인 제외)'");
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('identity_cancel_count');
        });
    }
};
