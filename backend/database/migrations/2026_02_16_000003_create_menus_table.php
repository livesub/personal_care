<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * 관리자 메뉴 마스터.
 * 명세: role(staff)에 따라 접근 가능 메뉴 제어용.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('menus', function (Blueprint $table) {
            $table->id()
                ->comment('메뉴 고유 식별자');
            $table->string('name', 50)->comment('메뉴 표시명');
            $table->string('route_name', 100)->comment('라우트 이름 (프론트/API 라우팅용)');
            $table->string('icon', 50)->nullable()->comment('아이콘 식별자 (Material Icons 등)');
            $table->boolean('is_staff_accessible')->default(true)->comment('staff 역할 접근 허용 여부. false면 super만 접근');
            $table->timestamps();
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE menus COMMENT = '관리자 메뉴 마스터 (권한별 노출)'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('menus');
    }
};
