<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * 이용자(Client) 등급(grade) 컬럼 추가. 행정관리 바우처 청구 내역용.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('clients', function (Blueprint $table): void {
            $table->string('grade', 20)->nullable()->after('disability_type')->comment('장애 등급 (정산·청구 내역 표시용)');
        });
    }

    public function down(): void
    {
        Schema::table('clients', function (Blueprint $table): void {
            $table->dropColumn('grade');
        });
    }
};
