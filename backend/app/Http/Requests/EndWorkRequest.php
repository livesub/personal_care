<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * 업무 종료 API. POST /api/user/end-work
 * - real_end_time: 실제 종료 시각 (필수).
 * - early_stop_reason: 조기 종료 시(real_end_time < matching.end_at) 컨트롤러에서 필수 검사.
 */
class EndWorkRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'real_end_time' => ['required', 'string', 'date'],
            'early_stop_reason' => ['nullable', 'string', 'max:2000'],
            'check_out_lat' => ['nullable', 'numeric', 'between:-90,90'],
            'check_out_lng' => ['nullable', 'numeric', 'between:-180,180'],
        ];
    }

    public function messages(): array
    {
        return [
            'real_end_time.required' => __('real_end_time_required'),
        ];
    }
}
