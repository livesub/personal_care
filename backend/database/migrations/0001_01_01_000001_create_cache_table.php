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
        Schema::create('cache', function (Blueprint $table) {
            $table->string('key')->primary()
                ->comment('캐시 키 (PK)');
            $table->mediumText('value')
                ->comment('캐시 값');
            $table->integer('expiration')->index()
                ->comment('만료 시각(Unix 타임스탬프)');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE cache COMMENT = '애플리케이션 캐시 저장'");
        }

        Schema::create('cache_locks', function (Blueprint $table) {
            $table->string('key')->primary()
                ->comment('락 키 (PK)');
            $table->string('owner')
                ->comment('락 소유자 식별자');
            $table->integer('expiration')->index()
                ->comment('락 만료 시각(Unix 타임스탬프)');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE cache_locks COMMENT = '캐시 락 (동시성 제어용)'");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('cache');
        Schema::dropIfExists('cache_locks');
    }
};
