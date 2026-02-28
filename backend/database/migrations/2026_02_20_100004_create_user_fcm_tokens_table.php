<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 보호사 FCM 디바이스 토큰. 종료 20분 전 푸시 발송용.
     */
    public function up(): void
    {
        Schema::create('user_fcm_tokens', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('user_id')->comment('보호사 user_id');
            $table->string('fcm_token', 500)->comment('FCM device token');
            $table->string('device_name', 100)->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'fcm_token']);
            $table->foreign('user_id')->references('user_id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_fcm_tokens');
    }
};
