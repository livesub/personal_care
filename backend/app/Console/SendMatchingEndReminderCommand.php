<?php

namespace App\Console;

use App\Models\Matching;
use App\Services\FcmReminderService;
use Carbon\Carbon;
use Illuminate\Console\Command;

/**
 * 종료 20분 전 매칭에 대해 보호사·보호자에게 FCM 푸시 알림 예약 발송.
 * 스케줄: 매 분 실행. end_at 이 now+19~21분 사이인 매칭만 처리.
 */
class SendMatchingEndReminderCommand extends Command
{
    protected $signature = 'matchings:send-end-reminder';

    protected $description = 'Send FCM push 20 minutes before each matching end_at to caregiver and guardian';

    public function __construct(
        private FcmReminderService $fcmReminder
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $now = Carbon::now();
        $windowStart = $now->copy()->addMinutes(19);
        $windowEnd = $now->copy()->addMinutes(21);

        $matchings = Matching::query()
            ->whereBetween('end_at', [$windowStart, $windowEnd])
            ->whereNull('real_end_time')
            ->with(['user', 'client'])
            ->get();

        foreach ($matchings as $matching) {
            $this->fcmReminder->sendEndReminder($matching);
        }

        if ($matchings->isEmpty()) {
            return self::SUCCESS;
        }

        $this->info(sprintf('Sent %d end-reminder(s).', $matchings->count()));

        return self::SUCCESS;
    }
}
