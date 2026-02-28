<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 관리자 보호사 등록 시 주민번호 없이 생성 가능하도록 nullable 처리.
     * MySQL 전용. SQLite는 스키마 제한으로 up에서 건너뜀.
     */
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() !== 'mysql') {
            return;
        }
        DB::statement('ALTER TABLE users MODIFY resident_no_suffix_hidden VARCHAR(255) NULL');
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() !== 'mysql') {
            return;
        }
        DB::statement('ALTER TABLE users MODIFY resident_no_suffix_hidden VARCHAR(255) NOT NULL');
    }
};
