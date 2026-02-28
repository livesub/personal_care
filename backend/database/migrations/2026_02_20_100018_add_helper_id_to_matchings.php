<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * matchings 테이블에 보호사(Helper) 전용 컬럼 helper_id 추가.
 * 기존 user_id는 보호사 user_id를 가리키지만, 역할이 명확한 helper_id를 추가해 조회 시 혼동 방지.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('matchings', 'helper_id')) {
            return;
        }

        Schema::table('matchings', function (Blueprint $table): void {
            $table->unsignedInteger('helper_id')->nullable()->after('id')
                ->comment('보호사(활동지원사) user_id. users.user_id와 동일.');
        });

        DB::table('matchings')->update(['helper_id' => DB::raw('user_id')]);
    }

    public function down(): void
    {
        if (! Schema::hasColumn('matchings', 'helper_id')) {
            return;
        }
        Schema::table('matchings', function (Blueprint $table): void {
            $table->dropColumn('helper_id');
        });
    }
};
