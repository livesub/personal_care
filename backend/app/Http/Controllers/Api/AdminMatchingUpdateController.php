<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateMatchingRequest;
use App\Models\CenterUserAffiliation;
use App\Models\Client;
use App\Models\Matching;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Schema;

/**
 * 매칭 수정. PATCH /api/admin/matchings/{id}
 * - 이미 시작되었거나 종료된 매칭은 start_at/end_at 변경 불가(필드 무시).
 */
class AdminMatchingUpdateController extends Controller
{
    public function __invoke(UpdateMatchingRequest $request, int $id): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
            ], 500);
        }

        $matching = Matching::where('id', $id)->where('center_id', $centerId)->first();
        if ($matching === null) {
            return response()->json(['message' => __('matching_not_found')], 404);
        }

        $now = Carbon::now();
        $startAt = $matching->start_at ? Carbon::parse($matching->start_at) : null;
        $canEditTime = $startAt && $now->lt($startAt);

        if (! $canEditTime && ($request->has('start_at') || $request->has('end_at'))) {
            return response()->json([
                'message' => __('matching_time_edit_forbidden'),
                'code' => 'MATCHING_TIME_EDIT_FORBIDDEN',
            ], 422);
        }

        // 프론트에서 온 텍스트 그대로 DB에 저장(시차 변환 없음)
        if ($request->has('start_at')) {
            $matching->start_at = $request->input('start_at');
        }
        if ($request->has('end_at')) {
            $matching->end_at = $request->input('end_at');
        }
        if ($request->has('hourly_wage')) {
            $matching->hourly_wage = (int) $request->input('hourly_wage');
        }

        // 폼에서 선택한 보호사 ID (auth()->id() 사용 금지). helper_id 또는 user_id
        $helperId = $request->has('helper_id') ? (int) $request->input('helper_id') : ($request->has('user_id') ? (int) $request->input('user_id') : null);
        if ($helperId !== null) {
            if (! CenterUserAffiliation::where('center_id', $centerId)->where('user_id', $helperId)->exists()) {
                return response()->json(['message' => __('matching_helper_not_in_center')], 422);
            }
            $matching->user_id = $helperId;
            if (Schema::hasColumn((new Matching)->getTable(), 'helper_id')) {
                $matching->helper_id = $helperId;
            }
        }
        if ($request->has('client_id')) {
            $clientId = (int) $request->input('client_id');
            if (! Client::where('id', $clientId)->where('center_id', $centerId)->exists()) {
                return response()->json(['message' => __('matching_client_not_in_center')], 422);
            }
            $matching->client_id = $clientId;
        }

        $matching->save();

        return response()->json([
            'message' => __('matching_updated'),
            'matching' => [
                'id' => $matching->id,
                'start_at' => $matching->start_at?->format('Y-m-d H:i:s'),
                'end_at' => $matching->end_at?->format('Y-m-d H:i:s'),
                'hourly_wage' => $matching->hourly_wage,
            ],
        ]);
    }
}
