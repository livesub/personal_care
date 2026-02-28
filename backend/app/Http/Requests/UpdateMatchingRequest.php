<?php

namespace App\Http\Requests;

use Carbon\Carbon;
use Illuminate\Foundation\Http\FormRequest;

/**
 * 매칭 수정. PATCH /api/admin/matchings/{id}
 * - 시작/종료된 매칭은 시간 필드 변경 불가(컨트롤러에서 검사).
 * - start_at 제출 시: 현재 시각 5분 버퍼 이후만 허용.
 */
class UpdateMatchingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        $startAtRules = [
            'sometimes',
            'string',
            'date',
            function (string $attribute, mixed $value, \Closure $fail): void {
                $cutoff = Carbon::now()->subMinutes(5);
                if (Carbon::parse($value)->lt($cutoff)) {
                    $fail(__('matching_start_must_be_future'));
                }
            },
        ];

        return [
            'helper_id' => ['sometimes', 'integer', 'min:1'],
            'user_id' => ['sometimes', 'integer', 'min:1'],
            'client_id' => ['sometimes', 'integer', 'min:1'],
            'start_at' => $startAtRules,
            'end_at' => ['sometimes', 'string', 'date'],
            'hourly_wage' => ['sometimes', 'integer', 'min:0'],
        ];
    }
}
