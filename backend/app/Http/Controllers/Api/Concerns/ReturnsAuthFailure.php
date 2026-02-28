<?php

namespace App\Http\Controllers\Api\Concerns;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

/**
 * 로그인 API 공통: 인증 실패 시 401 JSON 반환 로직.
 * HelperAuthController, AdminAuthController에서 중복 제거용.
 * 응답 형식: .cursorrules §5 (app, code, message, hint)
 */
trait ReturnsAuthFailure
{
    use ReturnsApiError;

    /** 인증 실패(비밀번호/사용자 없음) */
    private const CODE_UNAUTHORIZED = 'ERR_AUTH_001';

    /** 비활성 계정 등 접근 거부 */
    private const CODE_FORBIDDEN = 'ERR_AUTH_002';
    /**
     * 비밀번호 불일치 또는 사용자 없음 시 401 응답.
     * DB에 bcrypt 등 이전 해시가 남아 있으면 Argon2id가 예외를 던지므로, 그때는 bcrypt로 재검증.
     *
     * @param  object|null  $model  User 또는 Admin (password 속성 보유)
     * @param  string  $plainPassword  요청으로 받은 평문 비밀번호
     */
    protected function credentialsInvalid(?object $model, string $plainPassword): bool
    {
        if (! $model) {
            return true;
        }
        $stored = $model->password;
        if ($stored === null || $stored === '') {
            return true;
        }
        try {
            if (Hash::check($plainPassword, $stored)) {
                return false;
            }
        } catch (RuntimeException $e) {
            // Argon2id가 아닌 해시(예: bcrypt)일 때 예외 발생 → bcrypt로 재시도
        }
        try {
            if (Hash::driver('bcrypt')->check($plainPassword, $stored)) {
                return false;
            }
        } catch (\Throwable $e) {
            // ignore
        }
        return true;
    }

    /**
     * 상태가 active가 아니면 401 응답 반환, 아니면 null.
     *
     * @param  string  $status  user->status 또는 admin->status
     * @param  string  $message  비활성 시 클라이언트에 보낼 메시지
     * @return JsonResponse|null  401 응답 또는 null(통과)
     */
    protected function inactiveStatusResponse(string $status, string $message): ?JsonResponse
    {
        if ($status !== 'active') {
            return $this->errorResponse(
                self::CODE_FORBIDDEN,
                $message,
                'Account status is not active.',
                401
            );
        }

        return null;
    }

    /** 401 Unauthorized JSON 응답 생성 (표준 형식) */
    protected function unauthorized(string $message): JsonResponse
    {
        return $this->errorResponse(
            self::CODE_UNAUTHORIZED,
            $message,
            'Invalid credentials or user not found.',
            401
        );
    }
}
