<?php

namespace App\Http\Requests;

use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * 관리자 보호사 등록 API 검증.
 * POST /api/admin/users
 * - 기존 회원(login_id 존재): password 생략 가능. 소속만 추가 시 비밀번호 변경 없음.
 * - 신규 회원: password 필수.
 */
class StoreHelperRequest extends FormRequest
{
    /** 아이디 금칙어 (소문자 기준). AdminCompleteSetupRequest와 동일 */
    private const LOGIN_ID_BLACKLIST = ['admin', 'manager', 'root', 'staff', 'system'];

    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /** 휴대폰 번호는 하이픈 제거 후 숫자만 검증 (클라이언트가 010-1234-5678 또는 01012345678 전송 가능) */
    protected function prepareForValidation(): void
    {
        $loginId = $this->input('login_id');
        if (is_string($loginId)) {
            $this->merge(['login_id' => preg_replace('/\D/', '', $loginId)]);
        }
    }

    public function rules(): array
    {
        $loginId = preg_replace('/\D/', '', (string) $this->input('login_id', ''));
        $userExists = $loginId !== '' && User::where('login_id', $loginId)->exists();

        return [
            'login_id' => ['required', 'string', 'regex:/^[0-9]{10,11}$/'],
            'password' => [
                Rule::requiredIf(! $userExists),
                Rule::excludeIf($userExists),
                'string',
                'min:10',
            ],
            'name' => ['required', 'string', 'max:50'],
            'email' => ['required', 'email', 'max:100'],
        ];
    }

    public function messages(): array
    {
        return [
            'login_id.required' => __('admin_helper_login_id_required'),
            'login_id.regex' => __('admin_helper_login_id_phone'),
            'login_id.max' => __('helper_login_id_max'),
            'password.required' => __('admin_helper_password_required'),
            'password.min' => __('validation_password_min'),
            'name.required' => __('admin_helper_name_required'),
            'name.max' => __('admin_helper_name_max'),
            'email.required' => __('admin_helper_email_required'),
            'email.email' => __('admin_helper_email_email'),
            'email.max' => __('admin_helper_email_max'),
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $loginId = preg_replace('/\D/', '', (string) $this->input('login_id', ''));
            $loginIdLower = strtolower($loginId);
            if (in_array($loginIdLower, self::LOGIN_ID_BLACKLIST, true)) {
                $validator->errors()->add('login_id', __('admin_complete_setup_id_blocked'));
            }
        });
    }
}
