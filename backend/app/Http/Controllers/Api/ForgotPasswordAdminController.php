<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * 비밀번호 찾기 (관리자 전용).
 * 기획서 11~12p: 이름, 소속 센터, 아이디(휴대폰 번호), 받을 이메일.
 * 정보 일치 시 password_reset_tokens에 토큰 생성 후 입력받은 이메일로 재설정 딥링크 발송.
 */
class ForgotPasswordAdminController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $request->validate([
            'name' => ['required', 'string', 'max:50'],
            'center_id' => ['required', 'integer', 'exists:centers,id'],
            'login_id' => ['required', 'string', 'max:20'],
            'email' => ['required', 'email', 'max:100'],
        ], [
            'name.required' => __('forgot_name_required'),
            'center_id.required' => __('forgot_center_required'),
            'center_id.exists' => __('forgot_center_exists'),
            'login_id.required' => __('forgot_login_id_required'),
            'email.required' => __('forgot_email_required'),
            'email.email' => __('forgot_email_email'),
        ]);

        $loginId = preg_replace('/\D/', '', $request->input('login_id'));
        if ($loginId === '') {
            return response()->json(['message' => __('forgot_unmatched')], 422);
        }

        $admin = Admin::where('center_id', $request->input('center_id'))
            ->where('login_id', $loginId)
            ->where('name', $request->input('name'))
            ->first();

        if (! $admin) {
            return response()->json(['message' => __('forgot_unmatched')], 422);
        }

        $emailToSend = $request->input('email'); // 받을 이메일
        $token = Str::random(64);

        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $emailToSend],
            [
                'token' => Hash::make($token),
                'reset_type' => 'admin',
                'reset_id' => $admin->id,
                'created_at' => now(),
            ]
        );

        $resetUrl = $this->resetUrl($token, $emailToSend);

        try {
            \Illuminate\Support\Facades\Mail::to($emailToSend)->send(
                new \App\Mail\PasswordResetMail($resetUrl)
            );
        } catch (\Throwable $e) {
            report($e);
            return response()->json([
                'message' => __('forgot_email_send_failed'),
            ], 500);
        }

        return response()->json([
            'message' => __('forgot_email_sent'),
        ]);
    }

    private function resetUrl(string $token, string $email): string
    {
        $base = rtrim(config('app.frontend_url', config('app.url')), '/');
        $query = http_build_query(['token' => $token, 'email' => $email]);

        return $base . '/reset-password?' . $query;
    }
}
