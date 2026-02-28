<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 비밀번호 찾기 시 주민등록번호(앞6자리+뒤1자리) 검증용.
     * 기획서 11~12p.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('resident_no_prefix', 255)->nullable()->after('email')
                ->comment('주민번호 앞6자리 (AES-256 암호화). 비밀번호 찾기 본인 확인용.');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('resident_no_prefix');
        });
    }
};
