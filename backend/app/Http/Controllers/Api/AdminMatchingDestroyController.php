<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Matching;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 매칭 삭제. DELETE /api/admin/matchings/{id}
 * - 아직 시작 전(start_at > now)인 미래 스케줄만 삭제 허용.
 */
class AdminMatchingDestroyController extends Controller
{
    public function __invoke(Request $request, int $id): JsonResponse
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

        $startAt = $matching->start_at ? Carbon::parse($matching->start_at) : null;
        if ($startAt === null || ! Carbon::now()->lt($startAt)) {
            return response()->json([
                'message' => __('matching_delete_only_future'),
                'code' => 'MATCHING_DELETE_FORBIDDEN',
            ], 422);
        }

        $matching->delete();

        return response()->json(['message' => __('matching_deleted')]);
    }
}
