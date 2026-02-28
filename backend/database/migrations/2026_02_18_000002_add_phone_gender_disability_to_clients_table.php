<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 이용자(Client) 전화번호·성별·장애유형 컬럼 추가.
     * 성별은 주민번호 뒷자리 첫 숫자(1,3=M / 2,4=F)로 자동 파싱하여 저장.
     */
    public function up(): void
    {
        Schema::table('clients', function (Blueprint $table): void {
            $table->string('phone', 20)->nullable()->after('name')->comment('연락처 전화번호');
            $table->char('gender', 1)->nullable()->after('resident_no_suffix_hash')->comment('성별. M/F. 주민번호 첫 자리로 파싱');
            $table->string('disability_type', 50)->nullable()->after('gender')->comment('장애 유형');
        });
    }

    public function down(): void
    {
        Schema::table('clients', function (Blueprint $table): void {
            $table->dropColumn(['phone', 'gender', 'disability_type']);
        });
    }
};
