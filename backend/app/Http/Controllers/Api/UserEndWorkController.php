<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndWorkRequest;
use App\Models\Client;
use App\Models\Matching;
use App\Models\User;
use App\Services\VoucherCalculationService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;

/**
 * 보호사 업무 종료. POST /api/user/end-work
 * - 현재 시각 기준 진행 중인 매칭 1건에 real_end_time, early_stop_reason 저장.
 * - 조기 종료(real_end_time < end_at) 시 early_stop_reason 필수, 미입력 시 422.
 * - 저장 후 바우처 금액 계산하여 이용자 voucher_balance에서 즉시 차감.
 */
class UserEndWorkController extends Controller
{
    public function __invoke(EndWorkRequest $request, VoucherCalculationService $voucherCalc): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $matching = $this->getCurrentMatching($user);
        if ($matching === null) {
            return response()->json([
                'message' => __('no_current_matching'),
                'code' => 'NO_CURRENT_MATCHING',
            ], 404);
        }

        $realEndInput = $request->input('real_end_time');
        $realEnd = Carbon::parse($realEndInput);
        $endAt = $matching->end_at ? Carbon::parse($matching->end_at) : null;
        if ($endAt && $realEnd->lt($endAt)) {
            $reason = trim((string) $request->input('early_stop_reason', ''));
            if ($reason === '') {
                return response()->json([
                    'message' => __('early_stop_reason_required'),
                    'errors' => ['early_stop_reason' => [__('early_stop_reason_required')]],
                ], 422);
            }
        }

        $matching->real_end_time = $realEndInput;
        $matching->status = 'complete';
        $matching->actual_start_time = $matching->actual_start_time ?? $matching->start_at;
        $matching->early_stop_reason = trim((string) $request->input('early_stop_reason', '')) ?: null;
        if ($request->has('check_out_lat') && $request->has('check_out_lng')) {
            $matching->check_out_lat = $request->input('check_out_lat');
            $matching->check_out_lng = $request->input('check_out_lng');
        }
        $matching->save();

        $client = Client::withoutGlobalScopes()->find($matching->client_id);
        if ($client !== null) {
            $start = $matching->start_at ? Carbon::parse($matching->start_at) : null;
            $end = $matching->real_end_time ? Carbon::parse($matching->real_end_time) : ($matching->end_at ? Carbon::parse($matching->end_at) : null);
            if ($start && $end) {
                $amount = $voucherCalc->calculateAmount($start, $end);
                $client->decrement('voucher_balance', $amount);
            }
        }

        return response()->json([
            'message' => __('work_ended'),
            'matching' => [
                'id' => $matching->id,
                'real_end_time' => $matching->real_end_time->format('Y-m-d H:i:s'),
            ],
        ]);
    }

    private function getCurrentMatching(User $user): ?Matching
    {
        $now = Carbon::now();
        return Matching::where('user_id', $user->user_id)
            ->where('start_at', '<=', $now)
            ->where('end_at', '>=', $now)
            ->orderBy('end_at')
            ->first();
    }
}
