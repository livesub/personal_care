<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admins', function (Blueprint $table) {
            $table->id()
                ->comment('관리자 고유 식별자');
            $table->foreignId('center_id')->constrained('centers')->cascadeOnDelete()
                ->comment('소속 센터. centers 삭제 시 관리자도 삭제됨.');
            $table->string('login_id', 50)
                ->comment('로그인 ID. 센터별로 동일 ID 허용(복합 unique).');
            $table->unique(['center_id', 'login_id']);
            $table->string('password', 255)
                ->comment('해시 비밀번호. 평문 저장 시 보안 사고.');
            $table->string('name', 50)
                ->comment('관리자 성명');
            $table->string('email', 100)->nullable()
                ->comment('이메일 (선택). NOT NULL로 바꾸면 기존 레코드 UPDATE 필요.');
            $table->enum('status', ['active', 'suspended'])->default('active')
                ->comment('계정 상태. suspended 시 로그인 차단.');
            $table->timestamps();
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE admins COMMENT = '관리자 계정 (센터별). Sanctum tokenable'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('admins');
    }
};
