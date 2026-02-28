<?php

namespace App\Http\Requests;

use Carbon\Carbon;
use Illuminate\Foundation\Http\FormRequest;

/**
 * 매칭 등록 API 검증.
 * POST /api/admin/matchings
 * - helper_id 또는 user_id: 폼/선택박스에서 선택한 보호사 ID (관리자 ID 아님).
 * - client_id: 해당 센터 소속 이용자.
 * - 전역 중복 체크는 Controller에서 수행.
 * - start_at: 현재 시각보다 5분 이전(버퍼) 이후만 허용. (선택 후 전송까지 지연 시 UX 고려)
 */
class StoreMatchingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'helper_id' => ['required_without:user_id', 'integer', 'min:1'],
            'user_id' => ['required_without:helper_id', 'integer', 'min:1'],
            'client_id' => ['required', 'integer', 'min:1'],
            'start_at' => [
                'required',
                'string',
                'date',
                function (string $attribute, mixed $value, \Closure $fail): void {
                    $cutoff = Carbon::now()->subMinutes(5);
                    if (Carbon::parse($value)->lt($cutoff)) {
                        $fail(__('matching_start_must_be_future'));
                    }
                },
            ],
            'end_at' => ['required', 'string', 'date', 'after:start_at'],
            'hourly_wage' => ['required', 'integer', 'min:0'],
        ];
    }

    public function messages(): array
    {
        return [
            'helper_id.required_without' => __('matching_helper_required'),
            'user_id.required_without' => __('matching_helper_required'),
            'client_id.required' => __('matching_client_required'),
            'start_at.required' => __('matching_start_required'),
            'end_at.required' => __('matching_end_required'),
            'end_at.after' => __('matching_end_after_start'),
            'hourly_wage.required' => __('matching_wage_required'),
        ];
    }
}
