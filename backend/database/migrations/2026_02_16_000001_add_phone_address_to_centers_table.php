<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * centers 테이블에 phone, address 컬럼 추가.
 * 명세: 기관(센터) 정보 - 전화번호, 주소.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            $table->string('phone', 20)->nullable()->after('code')
                ->comment('센터 전화번호 (문의용)');
            $table->string('address', 255)->nullable()->after('phone')
                ->comment('센터 주소');
        });

        // code 컬럼은 기존 마이그레이션에서 이미 comment 있음. 필요 시 수동으로 center_code 의미 주석 추가.
    }

    public function down(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            $table->dropColumn(['phone', 'address']);
        });
    }
};
