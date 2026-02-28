<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 비밀번호 재설정 시 보호사/관리자 구분.
     * 기획서 11~12p.
     */
    public function up(): void
    {
        Schema::table('password_reset_tokens', function (Blueprint $table) {
            $table->string('reset_type', 10)->default('helper')->after('token')
                ->comment('helper=보호사, admin=관리자');
            $table->unsignedBigInteger('reset_id')->nullable()->after('reset_type')
                ->comment('user_id 또는 admins.id');
        });
    }

    public function down(): void
    {
        Schema::table('password_reset_tokens', function (Blueprint $table) {
            $table->dropColumn(['reset_type', 'reset_id']);
        });
    }
};
