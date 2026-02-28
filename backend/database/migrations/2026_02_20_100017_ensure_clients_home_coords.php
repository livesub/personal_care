<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * clients 테이블에 home_lat, home_lng 컬럼이 없을 경우 추가 (nullable).
 */
return new class extends Migration
{
    public function up(): void
    {
        $table = 'clients';
        if (! Schema::hasColumn($table, 'home_lat')) {
            Schema::table($table, function (Blueprint $table): void {
                $table->decimal('home_lat', 10, 8)->nullable()->comment('이용자 집 위도');
            });
        }
        if (! Schema::hasColumn($table, 'home_lng')) {
            Schema::table($table, function (Blueprint $table): void {
                $table->decimal('home_lng', 11, 8)->nullable()->comment('이용자 집 경도');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('clients', 'home_lat')) {
            Schema::table('clients', function (Blueprint $table): void {
                $table->dropColumn('home_lat');
            });
        }
        if (Schema::hasColumn('clients', 'home_lng')) {
            Schema::table('clients', function (Blueprint $table): void {
                $table->dropColumn('home_lng');
            });
        }
    }
};
