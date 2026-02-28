<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

/**
 * 최초 로그인 비밀번호 변경 (보호사 전용).
 * 성공 시 is_first_login = 0 처리.
 */
class ChangePasswordController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user instanceof User) {
            return response()->json(['message' => __('change_password_helper_only')], 403);
        }

        $request->validate([
            'password' => ['required', 'string', 'confirmed', Password::min(10)->letters()->numbers()->symbols()],
        ], [
            'password.required' => __('validation_password_required'),
            'password.confirmed' => __('validation_password_confirmed'),
            'password.min' => __('validation_password_min'),
        ]);

        // 기획서: 비밀번호 소문자 강제 변환 후 저장. 반드시 Hash::make() 후 저장.
        $password = \Illuminate\Support\Str::lower($request->input('password'));
        $hashed = Hash::make($password);
        User::where('user_id', $user->user_id)->update([
            'password' => $hashed,
            'is_first_login' => false,
        ]);

        return response()->json([
            'message' => __('change_password_success'),
        ]);
    }
}
