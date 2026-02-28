<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMatchingRequest;
use App\Models\CenterUserAffiliation;
use App\Models\Client;
use App\Models\Matching;
use App\Services\VoucherCalculationService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Schema;

/**
 * 매칭 등록 API.
 * POST /api/admin/matchings
 * - current_center_id 소속 보호사·이용자만 허용.
 * - 전역 중복: 해당 보호사의 모든 센터 스케줄과 시간 겹침 시 422, 저장 불가.
 */
class AdminMatchingStoreController extends Controller
{
    public function __invoke(StoreMatchingRequest $request, VoucherCalculationService $voucherCalc): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
                'hint' => 'current_center_id not set.',
            ], 500);
        }

        // 폼/선택박스에서 선택한 보호사 ID (auth()->id() 사용 금지)
        $helperId = (int) $request->input('helper_id', $request->input('user_id'));
        $clientId = (int) $request->input('client_id');
        // 중복/정산용 비교만 Carbon 사용. DB에는 프론트에서 온 텍스트 그대로 저장(변환 없음)
        $startAt = Carbon::parse($request->input('start_at'));
        $endAt = Carbon::parse($request->input('end_at'));
        $hourlyWage = (int) $request->input('hourly_wage');

        if (! CenterUserAffiliation::where('center_id', $centerId)->where('user_id', $helperId)->exists()) {
            return response()->json([
                'message' => __('matching_helper_not_in_center'),
                'errors' => ['helper_id' => [__('matching_helper_not_in_center')]],
            ], 422);
        }

        if (! Client::where('id', $clientId)->where('center_id', $centerId)->exists()) {
            return response()->json([
                'message' => __('matching_client_not_in_center'),
                'errors' => ['client_id' => [__('matching_client_not_in_center')]],
            ], 422);
        }

        $conflict = $this->findGlobalConflict($helperId, $startAt, $endAt);
        if ($conflict !== null) {
            return response()->json([
                'message' => __('matching_conflict_global'),
                'code' => 'MATCHING_CONFLICT',
                'errors' => ['schedule' => [__('matching_conflict_global')]],
            ], 422);
        }

        $createData = [
            'user_id' => $helperId,
            'center_id' => $centerId,
            'client_id' => $clientId,
            'start_at' => $request->input('start_at'),
            'end_at' => $request->input('end_at'),
            'hourly_wage' => $hourlyWage,
            'status' => 'scheduled',
        ];
        if (Schema::hasColumn((new Matching)->getTable(), 'helper_id')) {
            $createData['helper_id'] = $helperId;
        }
        $matching = Matching::create($createData);

        $payload = [
            'message' => __('matching_created'),
            'matching' => [
                'id' => $matching->id,
                'helper_id' => $matching->helper_id ?? $matching->user_id,
                'user_id' => $matching->user_id,
                'center_id' => $matching->center_id,
                'client_id' => $matching->client_id,
                'start_at' => $matching->start_at->format('Y-m-d H:i:s'), // DB 값 그대로 출력
                'end_at' => $matching->end_at->format('Y-m-d H:i:s'),
                'hourly_wage' => $matching->hourly_wage,
            ],
        ];

        $client = Client::find($clientId);
        if ($client !== null) {
            $estimatedAmount = $voucherCalc->calculateAmount($startAt, $endAt);
            $balance = (int) $client->voucher_balance;
            if ($balance < $estimatedAmount) {
                $payload['warning_insufficient_balance'] = true;
                $payload['estimated_amount'] = $estimatedAmount;
                $payload['client_balance'] = $balance;
                $payload['insufficient_message'] = __('voucher_insufficient_balance');
            }
        }

        return response()->json($payload, 201);
    }

    /**
     * 해당 보호사의 모든 센터 매칭 중 시간 겹침이 있으면 그 매칭 반환.
     * 겹침: (기존 시작 < 신규 종료) AND (기존 종료 > 신규 시작)
     */
    private function findGlobalConflict(int $userId, Carbon $newStart, Carbon $newEnd): ?Matching
    {
        return Matching::withoutGlobalScopes()
            ->where('user_id', $userId) // 보호사 ID 기준 중복 검사 (user_id/helper_id 동일 값)
            ->where(function ($q) use ($newStart, $newEnd) {
                $q->where('start_at', '<', $newEnd)
                    ->where('end_at', '>', $newStart);
            })
            ->first();
    }
}
