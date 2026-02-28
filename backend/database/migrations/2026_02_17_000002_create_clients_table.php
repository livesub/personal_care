<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 장애인 이용자(관리 대상). resident_no_suffix: 암호화 저장 + 검색용 해시 분리.
     */
    public function up(): void
    {
        Schema::create('clients', function (Blueprint $table) {
            $table->id()->comment('이용자 고유 식별자');
            $table->foreignId('center_id')->constrained('centers')->cascadeOnDelete()->comment('소속 센터');
            $table->string('name', 50)->comment('이용자 성명');
            $table->string('resident_no_suffix_hidden', 255)->comment('주민번호 뒷자리 (AES-256 암호화)');
            $table->string('resident_no_suffix_hash', 64)->comment('주민번호 뒷자리 SHA-256 해시. 검색/중복 체크용');
            $table->decimal('voucher_balance', 12, 0)->default(0)->comment('바우처 잔액');
            $table->enum('status', ['active', 'inactive'])->default('active')->comment('이용자 상태');
            $table->timestamps();
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE clients COMMENT = '장애인 이용자(관리 대상)'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('clients');
    }
};
