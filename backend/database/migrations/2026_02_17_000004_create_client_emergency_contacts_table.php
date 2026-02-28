<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 이용자(clients) 1:N 비상연락망.
     */
    public function up(): void
    {
        Schema::create('client_emergency_contacts', function (Blueprint $table) {
            $table->id()
                ->comment('비상연락처 고유 식별자');
            $table->foreignId('client_id')->constrained('clients')->cascadeOnDelete()
                ->comment('이용자 ID. 이용자 삭제 시 연락처도 삭제.');
            $table->string('name', 50)
                ->comment('연락처 이름 (예: 보호자 성명)');
            $table->string('phone', 20)
                ->comment('연락처 전화번호 (숫자만 저장 권장)');
            $table->string('relation', 30)->nullable()
                ->comment('관계 (예: 배우자, 자녀, 기타)');
            $table->unsignedTinyInteger('sort_order')->default(0)
                ->comment('표시 순서. 작을수록 우선.');
            $table->timestamps();
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE client_emergency_contacts COMMENT = '이용자별 비상연락처 1:N'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('client_emergency_contacts');
    }
};
