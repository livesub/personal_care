<?php

namespace App\Services;

use App\Models\Client;
use App\Models\Matching;
use App\Models\User;

/**
 * 매칭 종료 20분 전 FCM 푸시 알림 발송.
 * - 보호사(케어 제공자): user_id 기준 FCM 토큰으로 발송.
 * - 보호자: 이용자(client) 비상연락처 등으로 발송 가능. 현재는 로그만.
 * 실제 FCM 발송은 FcmSender 바인딩 시 구현.
 */
class FcmReminderService
{
    public function __construct(
        private $fcmSender = null
    ) {
    }

    public function sendEndReminder(Matching $matching): void
    {
        $user = $matching->user;
        $client = $matching->client;
        $endAt = $matching->end_at?->format('H:i');

        if ($user instanceof User) {
            $this->sendToCaregiver($user, $client, $endAt);
        }

        $this->sendToGuardian($matching, $client, $endAt);
    }

    private function sendToCaregiver(User $user, ?Client $client, ?string $endAt): void
    {
        $tokens = $this->getUserFcmTokens($user->user_id);
        $clientName = $client?->name ?? '';
        $title = __('fcm_reminder_title');
        $body = __('fcm_reminder_body_caregiver', ['time' => $endAt ?? '', 'client' => $clientName ?: '-']);

        if ($tokens === []) {
            return;
        }

        foreach ($tokens as $token) {
            $this->sendFcm($token, $title, $body);
        }
    }

    private function sendToGuardian(Matching $matching, ?Client $client, ?string $endAt): void
    {
        if (! $client) {
            return;
        }

        $guardianTokens = $this->getGuardianFcmTokens($client->id);
        $title = __('fcm_reminder_title');
        $body = __('fcm_reminder_body_guardian', ['time' => $endAt ?? '-']);

        if ($guardianTokens === []) {
            return;
        }

        foreach ($guardianTokens as $token) {
            $this->sendFcm($token, $title, $body);
        }
    }

    /**
     * 보호사 FCM 토큰 목록. user_fcm_tokens 테이블 사용.
     *
     * @return list<string>
     */
    private function getUserFcmTokens(int $userId): array
    {
        if (! \Illuminate\Support\Facades\Schema::hasTable('user_fcm_tokens')) {
            return [];
        }

        return \Illuminate\Support\Facades\DB::table('user_fcm_tokens')
            ->where('user_id', $userId)
            ->whereNotNull('fcm_token')
            ->where('fcm_token', '!=', '')
            ->pluck('fcm_token')
            ->all();
    }

    /**
     * 보호자(이용자 비상연락처 등) FCM 토큰. 별도 테이블 없으면 빈 배열.
     *
     * @return list<string>
     */
    private function getGuardianFcmTokens(int $clientId): array
    {
        return [];
    }

    private function sendFcm(string $token, string $title, string $body): void
    {
        if ($this->fcmSender !== null && method_exists($this->fcmSender, 'send')) {
            $this->fcmSender->send($token, $title, $body);
        }
    }
}
