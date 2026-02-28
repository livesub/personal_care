<?php

namespace App\Http\Controllers\Api\Concerns;

use Illuminate\Http\JsonResponse;

/**
 * API 에러 응답 표준 (.cursorrules §5).
 * 모든 에러 응답은 app, code, message, hint 형식으로 통일.
 */
trait ReturnsApiError
{
    /** 애플리케이션 이름 (에러 응답용) */
    private const APP_NAME = 'Personal Care';

    /**
     * 표준 API 에러 JSON 반환.
     *
     * @param  string  $code  고유 에러 코드 (예: ERR_AUTH_001)
     * @param  string  $message  사용자용 메시지 (언어팩 __() 사용)
     * @param  string  $hint  개발자용 힌트 (영문 등)
     * @param  int  $status  HTTP 상태 코드
     */
    protected function errorResponse(string $code, string $message, string $hint = '', int $status = 400): JsonResponse
    {
        $payload = [
            'app' => self::APP_NAME,
            'code' => $code,
            'message' => $message,
            'hint' => $hint ?: "Developer hint: {$code}",
        ];

        return response()->json($payload, $status);
    }
}
