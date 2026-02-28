<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\Concerns\ReturnsAuthFailure;
use App\Models\Matching;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * 보호사(Helper) 로그인 API. POST /api/helper/login. Guard/테이블 분리 명시.
 * - 보호사 로그인: users 테이블, login_id(휴대폰 번호) 필드로 인증. (Guard: web/sanctum for users)
 * - 관리자 로그인: admins 테이블, center_id + login_id → AdminAuthController. 두 로직 혼용 금지.
 */
class HelperAuthController extends Controller
{
    use ReturnsAuthFailure;

    private const FIRST_LOGIN_CACHE_PREFIX = 'first_login:';
    private const FIRST_LOGIN_TTL_SECONDS = 300; // 5분
    /**
     * login_id(숫자만)를 010-1234-5678 형식으로 포맷.
     * DB에는 숫자만 저장되므로 조회 후 포맷해서 반환.
     */
    private function formatPhone(string $loginId): string
    {
        $digits = preg_replace('/\D/', '', $loginId);
        if (strlen($digits) === 11 && str_starts_with($digits, '010')) {
            return substr($digits, 0, 3) . '-' . substr($digits, 3, 4) . '-' . substr($digits, 7, 4);
        }
        return $loginId;
    }

    /**
     * 현재 시각 기준 배정된 매칭 1건 조회 (start_at <= now() <= end_at).
     * 없으면 null. 여러 건이면 첫 번째 사용 (추후 수동 선택 로직 확장 가능).
     */
    private function getCurrentMatching(User $user): ?Matching
    {
        $now = Carbon::now();
        return Matching::where('user_id', $user->user_id)
            ->where('start_at', '<=', $now)
            ->where('end_at', '>=', $now)
            ->with('center')
            ->orderBy('end_at')
            ->first();
    }

    /**
     * 보호사 로그인.
     * 수동 유저 조회 → Hash 체크 → status 검증. 실패 시 실무용 메시지만 반환.
     */
    public function login(Request $request): JsonResponse
    {
        $rawLoginId = $request->input('login_id') ?? $request->input('phone');
        if ($rawLoginId === null || (is_string($rawLoginId) && trim($rawLoginId) === '')) {
            throw ValidationException::withMessages([
                'login_id' => [__('helper_login_id_required')],
            ]);
        }
        $request->validate(
            [
                'password' => ['required', 'string'],
                'device_name' => ['nullable', 'string', 'max:100'],
            ],
            [
                'password.required' => __('helper_login_password_required'),
            ]
        );

        $rawStr = is_string($rawLoginId) ? $rawLoginId : (string) $rawLoginId;
        $loginId = str_replace(['-', ' ', '\t'], '', $rawStr);
        $loginId = preg_replace('/\D/', '', $loginId);
        if ($loginId === '') {
            throw ValidationException::withMessages([
                'login_id' => [__('helper_login_id_required')],
            ]);
        }
        if (! preg_match('/^[0-9]{10,11}$/', $loginId)) {
            throw ValidationException::withMessages([
                'login_id' => [__('helper_login_id_phone_format')],
            ]);
        }

        $user = User::where('login_id', $loginId)->first();
        if ($user === null && strlen($loginId) === 11 && str_starts_with($loginId, '010')) {
            $user = User::where('login_id', ltrim($loginId, '0'))->first();
        }

        if ($user === null) {
            return $this->unauthorized(__('auth_failed'));
        }

        $plainPassword = \Illuminate\Support\Str::lower($request->input('password'));
        $dbPassword = $user->getRawOriginal('password') ?: $user->password;
        $hashCheck = \Illuminate\Support\Facades\Hash::check($plainPassword, $dbPassword);
        if (! $hashCheck) {
            try {
                $hashCheck = \Illuminate\Support\Facades\Hash::driver('bcrypt')->check($plainPassword, $dbPassword);
            } catch (\Throwable $e) {
                // ignore
            }
        }
        if (! $hashCheck) {
            return $this->unauthorized(__('auth_failed'));
        }

        if ($user->status !== 'active') {
            return $this->inactiveStatusResponse($user->status, __('auth_inactive_helper'));
        }

        if (\Illuminate\Support\Facades\Hash::needsRehash($user->password)) {
            $user->update(['password' => $plainPassword]);
        }

        $matching = $this->getCurrentMatching($user);
        $center = $matching?->center;

        $userPayload = [
            'user_id' => $user->user_id,
            'name' => $user->name,
            'email' => $user->email,
            'phone_formatted' => $this->formatPhone($user->login_id),
            'center_id' => $center?->id,
            'center_name' => $center?->name,
            'end_at' => $matching?->end_at?->format('Y-m-d H:i:s'),
        ];

        // 최초 로그인: 토큰 발급 금지. need_password_change + temporary_token만 반환.
        if ($user->is_first_login) {
            $prefix = (string) ($user->resident_no_prefix ?? '');
            $suffixRaw = (string) ($user->resident_no_suffix_hidden ?? '');
            $suffixFirst = $suffixRaw !== '' ? substr($suffixRaw, 0, 1) : '';
            $userPayload['resident_masked'] = ($prefix !== '' && $suffixFirst !== '') ? $prefix . '-' . $suffixFirst . '****' : null;

            $temporaryToken = Str::random(64);
            Cache::put(self::FIRST_LOGIN_CACHE_PREFIX . $temporaryToken, $user->user_id, self::FIRST_LOGIN_TTL_SECONDS);

            return response()->json([
                'need_password_change' => true,
                'temporary_token' => $temporaryToken,
                'user' => $userPayload,
            ]);
        }

        $deviceName = $request->input('device_name', 'flutter-app');
        $token = $user->createToken($deviceName)->plainTextToken;

        $payload = [
            'access_token' => $token,
            'token_type' => 'Bearer',
            'is_first_login' => false,
            'user' => $userPayload,
        ];

        if (! $matching) {
            $payload['message'] = __('helper_no_matching');
        }

        return response()->json($payload);
    }
}
