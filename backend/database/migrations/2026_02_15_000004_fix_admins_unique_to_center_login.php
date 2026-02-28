<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * admins: login_id 단일 UNIQUE 제거 → (center_id, login_id) 복합 UNIQUE로 변경.
 * 이미 000003이 복합 unique로 테이블을 만든 경우( migrate:fresh 후) 인덱스가 없을 수 있으므로 존재할 때만 drop.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }
        $indexes = DB::select("SHOW INDEX FROM admins WHERE Key_name = 'admins_login_id_unique'");
        if (count($indexes) > 0) {
            Schema::table('admins', function (Blueprint $table) {
                $table->dropUnique('admins_login_id_unique');
            });
        }

        $composite = DB::select("SHOW INDEX FROM admins WHERE Key_name = 'admins_center_login_unique'");
        if (count($composite) === 0) {
            Schema::table('admins', function (Blueprint $table) {
                $table->unique(['center_id', 'login_id'], 'admins_center_login_unique');
            });
        }
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }
        Schema::table('admins', function (Blueprint $table) {
            $table->dropUnique('admins_center_login_unique');
            $table->unique('login_id', 'admins_login_id_unique');
        });
    }
};
