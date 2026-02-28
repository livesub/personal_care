<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * 센터 내부 공지사항. 운영 관리 — 센터 전용 공지.
 * 데이터 격리: Notice 모델에서 center_id 기준 Global Scope 적용.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notices', function (Blueprint $table) {
            $table->id()
                ->comment('공지 고유 식별자');
            $table->foreignId('center_id')->constrained('centers')->cascadeOnDelete()
                ->comment('센터 FK');
            $table->string('title', 255)
                ->comment('제목');
            $table->text('content')
                ->comment('내용');
            $table->timestamps();
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE notices COMMENT = '센터 내부 공지. center_id 격리'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('notices');
    }
};
