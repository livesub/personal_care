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
        Schema::create('jobs', function (Blueprint $table) {
            $table->id()
                ->comment('잡 레코드 고유 식별자');
            $table->string('queue')->index()
                ->comment('큐 이름');
            $table->longText('payload')
                ->comment('잡 데이터 페이로드');
            $table->unsignedTinyInteger('attempts')
                ->comment('시도 횟수');
            $table->unsignedInteger('reserved_at')->nullable()
                ->comment('예약(처리 중) 시각(Unix 타임스탬프)');
            $table->unsignedInteger('available_at')
                ->comment('실행 가능 시각(Unix 타임스탬프)');
            $table->unsignedInteger('created_at')
                ->comment('생성 시각(Unix 타임스탬프)');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE jobs COMMENT = '큐 잡 저장 (비동기 처리용)'");
        }

        Schema::create('job_batches', function (Blueprint $table) {
            $table->string('id')->primary()
                ->comment('배치 ID (PK)');
            $table->string('name')
                ->comment('배치 이름');
            $table->integer('total_jobs')
                ->comment('전체 잡 수');
            $table->integer('pending_jobs')
                ->comment('대기 중 잡 수');
            $table->integer('failed_jobs')
                ->comment('실패한 잡 수');
            $table->longText('failed_job_ids')
                ->comment('실패한 잡 ID 목록');
            $table->mediumText('options')->nullable()
                ->comment('배치 옵션');
            $table->integer('cancelled_at')->nullable()
                ->comment('취소 시각(Unix 타임스탬프)');
            $table->integer('created_at')
                ->comment('생성 시각(Unix 타임스탬프)');
            $table->integer('finished_at')->nullable()
                ->comment('완료 시각(Unix 타임스탬프)');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE job_batches COMMENT = '잡 배치 메타정보'");
        }

        Schema::create('failed_jobs', function (Blueprint $table) {
            $table->id()
                ->comment('레코드 고유 식별자');
            $table->string('uuid')->unique()
                ->comment('잡 UUID');
            $table->text('connection')
                ->comment('연결 이름');
            $table->text('queue')
                ->comment('큐 이름');
            $table->longText('payload')
                ->comment('잡 페이로드');
            $table->longText('exception')
                ->comment('예외 메시지/스택');
            $table->timestamp('failed_at')->useCurrent()
                ->comment('실패 발생 시각');
        });

        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            DB::statement("ALTER TABLE failed_jobs COMMENT = '실패한 잡 기록'");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('jobs');
        Schema::dropIfExists('job_batches');
        Schema::dropIfExists('failed_jobs');
    }
};
