<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

/**
 * 비밀번호 재설정 (이메일 링크 클릭 후).
 * 기획서: 토큰 검증 후 새 비밀번호 저장, 반드시 소문자로 변환 후 Argon2id 저장.
 * reset_type에 따라 User(보호사) 또는 Admin(관리자) 비밀번호 갱신.
 */
class ResetPasswordController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'email', 'max:100'],
            'token' => ['required', 'string'],
            'password' => ['required', 'string', 'confirmed', Password::min(10)->letters()->numbers()->symbols()],
        ], [
            'email.required' => __('reset_email_required'),
            'token.required' => __('reset_token_required'),
            'password.required' => __('validation_password_required'),
            'password.confirmed' => __('validation_password_confirmed'),
            'password.min' => __('validation_password_min'),
        ]);

        $email = $request->input('email');
        $record = DB::table('password_reset_tokens')->where('email', $email)->first();

        if (! $record || ! Hash::check($request->input('token'), $record->token)) {
            throw ValidationException::withMessages([
                'token' => [__('reset_token_invalid')],
            ]);
        }

        // 기획서: 소문자 강제 변환 후 Argon2id 암호화 저장
        $plain = \Illuminate\Support\Str::lower($request->input('password'));
        $hashed = $this->hashWithArgon2id($plain);

        $resetType = $record->reset_type ?? 'helper';
        $resetId = $record->reset_id;

        if ($resetType === 'admin' && $resetId !== null) {
            $affected = DB::table('admins')->where('id', $resetId)->update(['password' => $hashed]);
            if ($affected === 0) {
                DB::table('password_reset_tokens')->where('email', $email)->delete();
                throw ValidationException::withMessages([
                    'email' => [__('reset_email_no_account')],
                ]);
            }
        } else {
            $userId = $resetId;
            if ($userId === null) {
                $user = User::where('email', $email)->first();
                $userId = $user?->user_id;
            }
            if ($userId === null) {
                DB::table('password_reset_tokens')->where('email', $email)->delete();
                throw ValidationException::withMessages([
                    'email' => [__('reset_email_no_account')],
                ]);
            }
            $affected = DB::table('users')->where('user_id', $userId)->update(['password' => $hashed]);
            if ($affected === 0) {
                DB::table('password_reset_tokens')->where('email', $email)->delete();
                throw ValidationException::withMessages([
                    'email' => [__('reset_email_no_account')],
                ]);
            }
        }

        DB::table('password_reset_tokens')->where('email', $email)->delete();

        return response()->json([
            'message' => __('reset_success'),
        ]);
    }

    /**
     * Argon2id 방식으로 암호화 (기획서 요구).
     */
    private function hashWithArgon2id(string $password): string
    {
        if (defined('PASSWORD_ARGON2ID')) {
            return password_hash($password, PASSWORD_ARGON2ID);
        }

        return Hash::make($password);
    }
}
