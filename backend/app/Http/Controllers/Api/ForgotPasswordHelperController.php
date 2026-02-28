<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * 비밀번호 찾기 (보호사 전용).
 * 기획서 11~12p: 이름, 아이디(휴대폰), 주민등록번호(앞6자리+뒤1자리), 받을 이메일.
 * 정보 일치 시 password_reset_tokens에 토큰 생성 후 입력받은 이메일로 재설정 딥링크 발송.
 */
class ForgotPasswordHelperController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $request->validate([
            'name' => ['required', 'string', 'max:50'],
            'login_id' => ['required', 'string', 'max:20'],
            'resident_no_prefix' => ['required', 'string', 'size:6', 'regex:/^\d{6}$/'],
            'resident_no_suffix_first' => ['required', 'string', 'size:1', 'regex:/^\d$/'],
            'email' => ['required', 'email', 'max:100'],
        ], [
            'name.required' => __('forgot_name_required'),
            'login_id.required' => __('forgot_login_id_required'),
            'resident_no_prefix.required' => __('forgot_resident_prefix_required'),
            'resident_no_prefix.regex' => __('forgot_resident_prefix_regex'),
            'resident_no_suffix_first.required' => __('forgot_resident_suffix_required'),
            'resident_no_suffix_first.regex' => __('forgot_resident_suffix_regex'),
            'email.required' => __('forgot_email_required'),
            'email.email' => __('forgot_email_email'),
        ]);

        $loginId = preg_replace('/\D/', '', $request->input('login_id'));
        if ($loginId === '') {
            return response()->json(['message' => __('forgot_unmatched')], 422);
        }

        $user = User::where('login_id', $loginId)
            ->where('name', $request->input('name'))
            ->where('status', 'active')
            ->first();

        if (! $user) {
            return response()->json(['message' => __('forgot_unmatched')], 422);
        }

        // 주민번호(rrn) 비교 로직: 앞6자리 + 뒤1자리
        $prefixInput = $request->input('resident_no_prefix');
        $suffixFirstInput = $request->input('resident_no_suffix_first');
        if (! $this->verifyResidentNo($user, $prefixInput, $suffixFirstInput)) {
            return response()->json(['message' => __('forgot_unmatched')], 422);
        }

        $emailToSend = $request->input('email'); // 받을 이메일
        $token = Str::random(64);

        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $emailToSend],
            [
                'token' => Hash::make($token),
                'reset_type' => 'helper',
                'reset_id' => $user->user_id,
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

    /**
     * 주민등록번호 앞6자리·뒤1자리 검증.
     */
    private function verifyResidentNo(User $user, string $prefixInput, string $suffixFirstInput): bool
    {
        if ($user->resident_no_prefix !== null) {
            $storedPrefix = $user->resident_no_prefix;
            if ($storedPrefix !== $prefixInput) {
                return false;
            }
        }
        $suffixHidden = $user->resident_no_suffix_hidden;
        if ($suffixHidden === null || $suffixHidden === '') {
            return false;
        }
        $firstChar = mb_substr($suffixHidden, 0, 1);

        return $firstChar === $suffixFirstInput;
    }

    private function resetUrl(string $token, string $email): string
    {
        $base = rtrim(config('app.frontend_url', config('app.url')), '/');
        $query = http_build_query(['token' => $token, 'email' => $email]);

        return $base . '/reset-password?' . $query;
    }
}
