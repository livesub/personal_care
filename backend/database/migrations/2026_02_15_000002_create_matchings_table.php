<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('matchings', function (Blueprint $table) {
            $table->id()
                ->comment('배정 고유 식별자');
            $table->unsignedInteger('user_id')
                ->comment('보호사 user_id. users.user_id 변경 시 FK 오류 발생.');
            $table->foreignId('center_id')->constrained('centers')->cascadeOnDelete()
                ->comment('배정된 센터. centers 삭제 시 배정도 삭제됨.');
            $table->dateTime('start_at')
                ->comment('근무 시작 시각. 로그인/세션 전환 시 현재 시각이 start_at~end_at 사이인 배정 사용.');
            $table->dateTime('end_at')
                ->comment('근무 종료 시각. end_at 20분 전까지 앱에서 일지 작성/종료 버튼 비활성화.');
            $table->timestamp('created_at')->nullable()
                ->comment('레코드 생성 시각');
            $table->timestamp('updated_at')->nullable()
                ->comment('레코드 수정 시각');
            $table->foreign('user_id')->references('user_id')->on('users')->cascadeOnDelete();
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE matchings COMMENT = '보호사-센터 배정(스케줄). 현재 시각 기준 배정으로 세션 전환'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('matchings');
    }
};
