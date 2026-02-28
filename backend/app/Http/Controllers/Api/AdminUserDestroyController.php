<?php

namespace App\Http\Controllers\Api;

use App\Models\CenterUserAffiliation;
use App\Models\Matching;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 관리자 보호사 삭제(현재 센터 소속 해제) API.
 * DELETE /api/admin/users/{id}
 * - 해당 user가 current_center_id 소속인지 확인.
 * - 타 센터 포함 전 센터 일정(매칭)이 하나라도 있으면 422 반환.
 * - 일정이 없을 때만 현재 센터 소속만 해제(affiliation 삭제).
 */
class AdminUserDestroyController extends Controller
{
    public function __invoke(Request $request, int $id): JsonResponse
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

        $affiliation = CenterUserAffiliation::where('center_id', $centerId)->where('user_id', $id)->first();
        if (! $affiliation) {
            return response()->json([
                'message' => __('admin_delete_forbidden'),
                'errors' => ['user_id' => [__('admin_delete_forbidden')]],
            ], 403);
        }

        // 오늘 이후 포함 전 센터 일정(매칭) 존재 여부 검사
        $matchings = Matching::where('user_id', $id)->get();
        if ($matchings->isNotEmpty()) {
            $hasOurCenter = $matchings->contains('center_id', $centerId);
            $message = $hasOurCenter
                ? __('admin_delete_has_schedules')
                : __('admin_delete_has_other_center_schedules');
            return response()->json([
                'message' => $message,
                'errors' => ['user_id' => [$message]],
            ], 422);
        }

        $affiliation->delete();

        return response()->json([
            'message' => __('admin_delete_success'),
        ], 200);
    }
}
