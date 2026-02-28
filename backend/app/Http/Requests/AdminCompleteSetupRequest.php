<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * 관리자 새 아이디 저장 시 검증 (StoreAdmin 동일 규칙).
 * POST /api/admin/complete-setup
 * - new_login_id: 1) unique:admins,login_id (전역) 2) 금지어 3) admin_ 접두사 불가(시스템용).
 */
class AdminCompleteSetupRequest extends FormRequest
{
    /** 금지어(Blacklist): admin, staff, manager, root, system 사용 불가 */
    private const LOGIN_ID_BLACKLIST = ['admin', 'staff', 'manager', 'root', 'system'];

    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'new_login_id' => ['required', 'string', 'max:50', Rule::unique('admins', 'login_id')],
            'new_password' => ['required', 'string', 'min:10', 'confirmed'],
        ];
    }

    public function messages(): array
    {
        return [
            'new_login_id.required' => __('helper_login_id_required'),
            'new_login_id.unique' => __('admin_login_id_taken'),
            'new_password.required' => __('validation_password_required'),
            'new_password.confirmed' => __('validation_password_confirmed'),
            'new_password.min' => __('validation_password_min'),
        ];
    }

    /** unique 검사 시 소문자로 비교 (DB 저장도 소문자이므로). */
    protected function prepareForValidation(): void
    {
        $id = $this->input('new_login_id');
        if (is_string($id)) {
            $this->merge(['new_login_id' => strtolower($id)]);
        }
    }

    /** 추가 검증: 금지어 + admin_ 접두사(시스템용) 차단 */
    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $loginId = strtolower((string) $this->input('new_login_id', ''));
            if (in_array($loginId, self::LOGIN_ID_BLACKLIST, true)) {
                $validator->errors()->add('new_login_id', __('admin_complete_setup_id_blocked'));
                return;
            }
            if (str_starts_with($loginId, 'admin_')) {
                $validator->errors()->add('new_login_id', __('admin_login_id_prefix_reserved'));
            }
        });
    }
}
