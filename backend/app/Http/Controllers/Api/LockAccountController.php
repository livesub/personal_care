<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\ValidationException;

/**
 * 최초 로그인 비밀번호 변경 팝업에서 3회 취소 시 계정 잠금.
 * POST /api/auth/lock-account (인증 없음, temporary_token으로 유저 식별)
 * - users.status → 'suspended'
 * - 해당 유저의 모든 Sanctum 토큰 파기
 * - 캐시의 temporary_token 삭제
 */
class LockAccountController extends Controller
{
    private const CACHE_PREFIX = 'first_login:';

    public function __invoke(Request $request): JsonResponse
    {
        $request->validate([
            'temporary_token' => ['required', 'string', 'size:64'],
        ], [
            'temporary_token.required' => __('lock_session_expired'),
        ]);

        $key = self::CACHE_PREFIX . $request->input('temporary_token');
        $userId = Cache::get($key);

        if ($userId === null) {
            throw ValidationException::withMessages([
                'temporary_token' => [__('lock_session_expired')],
            ]);
        }

        $user = User::find($userId);
        if (! $user) {
            Cache::forget($key);
            return response()->json(['message' => __('lock_processed')], 200);
        }

        $user->update(['status' => 'suspended']);
        $user->tokens()->delete();
        Cache::forget($key);

        $centerName = null;
        $matching = $user->matchings()
            ->where('end_at', '>=', now())
            ->with('center')
            ->orderBy('end_at')
            ->first();
        if ($matching?->center) {
            $centerName = $matching->center->name;
        }
        if (! $centerName) {
            $matching = $user->matchings()->with('center')->latest('end_at')->first();
            if ($matching?->center) {
                $centerName = $matching->center->name;
            }
        }

        return response()->json([
            'message' => __('lock_account_locked'),
            'center_name' => $centerName,
        ]);
    }
}
