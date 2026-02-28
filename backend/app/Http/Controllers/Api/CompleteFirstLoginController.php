<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

/**
 * 최초 로그인 비밀번호 변경 (토큰 기반, 인증 없음).
 * need_password_change 응답 후 temporary_token으로 호출. 성공 시 is_first_login = 0.
 */
class CompleteFirstLoginController extends Controller
{
    private const CACHE_PREFIX = 'first_login:';

    public function __invoke(Request $request): JsonResponse
    {
        $request->validate([
            'temporary_token' => ['required', 'string', 'size:64'],
            'password' => ['required', 'string', 'confirmed', Password::min(10)->letters()->numbers()->symbols()],
        ], [
            'temporary_token.required' => __('first_login_session_expired'),
            'password.required' => __('validation_password_required'),
            'password.confirmed' => __('validation_password_confirmed'),
            'password.min' => __('validation_password_min'),
        ]);

        $key = self::CACHE_PREFIX . $request->input('temporary_token');
        $userId = Cache::get($key);

        if ($userId === null) {
            throw ValidationException::withMessages([
                'temporary_token' => [__('first_login_session_expired')],
            ]);
        }

        $user = User::find($userId);
        if (! $user || ! $user->is_first_login) {
            Cache::forget($key);
            throw ValidationException::withMessages([
                'temporary_token' => [__('first_login_invalid')],
            ]);
        }

        $password = \Illuminate\Support\Str::lower($request->input('password'));
        // 반드시 Hash::make() 후 저장. 모델 cast만 의존 시 환경에 따라 누락될 수 있으므로 명시적 저장.
        $hashed = Hash::make($password);
        User::where('user_id', $user->user_id)->update([
            'password' => $hashed,
            'is_first_login' => false,
        ]);

        Cache::forget($key);

        return response()->json([
            'message' => __('first_login_success'),
        ]);
    }
}
