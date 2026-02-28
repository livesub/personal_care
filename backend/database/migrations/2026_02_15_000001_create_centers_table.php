<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('centers', function (Blueprint $table) {
            $table->id()
                ->comment('센터 고유 식별자');
            $table->string('name', 100)
                ->comment('센터명 (화면 표시용)');
            $table->string('code', 20)->unique()
                ->comment('센터 코드 (API/관리자 로그인 시 전송용). 변경 시 클라이언트 캐시와 불일치할 수 있음.');
            $table->timestamps();
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE centers COMMENT = '센터(근무지) 마스터'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('centers');
    }
};
