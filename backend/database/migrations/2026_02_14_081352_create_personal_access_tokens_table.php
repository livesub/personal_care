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
        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id()
                ->comment('토큰 레코드 고유 식별자');
            $table->string('tokenable_type')
                ->comment('소유 모델 클래스 (예: App\\Models\\User)');
            $table->unsignedBigInteger('tokenable_id')
                ->comment('소유 모델 PK (예: user_id)');
            $table->text('name')
                ->comment('토큰 이름/용도');
            $table->string('token', 64)->unique()
                ->comment('API Bearer 토큰 해시');
            $table->text('abilities')->nullable()
                ->comment('권한 목록 (JSON 등)');
            $table->timestamp('last_used_at')->nullable()
                ->comment('마지막 사용 시각');
            $table->timestamp('expires_at')->nullable()->index()
                ->comment('토큰 만료 시각');
            $table->timestamp('created_at')->nullable()
                ->comment('레코드 생성 시각');
            $table->timestamp('updated_at')->nullable()
                ->comment('레코드 수정 시각');
        });

        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->index(['tokenable_type', 'tokenable_id']);
        });
        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE personal_access_tokens COMMENT = 'Laravel Sanctum API 토큰 (Bearer 인증용)'");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('personal_access_tokens');
    }
};
