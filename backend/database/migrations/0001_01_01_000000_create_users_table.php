<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->integer('user_id', true, true)
                ->comment('시스템 고유 식별자');
            $table->string('login_id', 20)->unique()
                ->comment('로그인 ID이자 실제 연락처. DB에는 하이픈(-)을 제거한 숫자만 저장(예: 01012345678). 별도의 phone 컬럼은 없음. 차후 알림톡/SMS 발송 및 아이디 검증용.');
            $table->string('password', 255)
                ->comment('Argon2id 해싱. 초기값은 관리자가 설정.');
            $table->string('name', 50)
                ->comment('보호사 성명');
            $table->string('email', 100)
                ->comment('비밀번호 찾기 및 계정 관리용 필수 이메일 (모든 사용자 필수)');
            $table->string('resident_no_suffix_hidden', 255)
                ->comment('주민번호 뒷자리 (AES-256 암호화)');
            $table->enum('status', ['active', 'suspended', 'withdrawn'])->default('active')
                ->comment('계정 상태');
            $table->boolean('is_first_login')->default(true)
                ->comment('1:최초 로그인(비번 변경 필요), 0:정상');
            $table->rememberToken()
                ->comment('웹 로그인 시 "로그인 유지"용 토큰 (API 전용 시 미사용)');
            $table->timestamp('created_at')->nullable()
                ->comment('레코드 생성 시각');
            $table->timestamp('updated_at')->nullable()
                ->comment('레코드 수정 시각');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE users COMMENT = '보호사 계정 정보 (장애인 제외)'");
        }

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary()
                ->comment('비밀번호 재설정 요청 이메일 (PK)');
            $table->string('token')
                ->comment('재설정용 일회성 토큰');
            $table->timestamp('created_at')->nullable()
                ->comment('토큰 생성 시각');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE password_reset_tokens COMMENT = '비밀번호 재설정 요청 토큰 저장'");
        }

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary()
                ->comment('세션 ID (PK)');
            $table->foreignId('user_id')->nullable()->index()
                ->comment('로그인한 users.user_id (nullable: 비로그인 세션)');
            $table->string('ip_address', 45)->nullable()
                ->comment('클라이언트 IP');
            $table->text('user_agent')->nullable()
                ->comment('클라이언트 User-Agent');
            $table->longText('payload')
                ->comment('세션 데이터 페이로드');
            $table->integer('last_activity')->index()
                ->comment('마지막 활동 시각(Unix 타임스탬프)');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE sessions COMMENT = '웹 세션 저장 (Laravel 기본)'");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('users');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('sessions');
    }
};
