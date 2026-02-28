<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 보호사(users) - 센터(centers) N:M 소속. Unique(center_id, user_id).
     */
    public function up(): void
    {
        Schema::create('center_user_affiliation', function (Blueprint $table) {
            $table->id()->comment('소속 매핑 고유 식별자');
            $table->foreignId('center_id')->constrained('centers')->cascadeOnDelete()->comment('센터 ID');
            $table->unsignedInteger('user_id')->comment('보호사 user_id');
            $table->timestamps();

            $table->foreign('user_id')->references('user_id')->on('users')->cascadeOnDelete();
            $table->unique(['center_id', 'user_id'], 'center_user_affiliation_center_id_user_id_unique');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE center_user_affiliation COMMENT = '보호사-센터 N:M 소속'");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('center_user_affiliation');
    }
};
