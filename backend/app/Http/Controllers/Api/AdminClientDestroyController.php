<?php

namespace App\Http\Controllers\Api;

use App\Models\Client;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 이용자(장애인) 삭제 API.
 * DELETE /api/admin/clients/{id}
 * - current_center_id 소속만 삭제 가능.
 * - 향후 매칭 일정 존재 시 삭제 차단 (현재 matchings 테이블에 client_id 없음 시 삭제 허용).
 */
class AdminClientDestroyController extends Controller
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

        $client = Client::withoutGlobalScope('center')
            ->where('center_id', $centerId)
            ->where('id', $id)
            ->first();

        if (! $client) {
            return response()->json([
                'message' => __('admin_client_not_found'),
                'errors' => ['id' => [__('admin_client_not_found')]],
            ], 404);
        }

        // 향후 매칭 일정 존재 시 삭제 차단 (client_id 연동 시 여기서 조회)
        // 현재 matchings 테이블에는 user_id(보호사)만 있으므로 client 쪽 일정 체크는 확장 시 추가

        $client->delete();

        return response()->json([
            'message' => __('admin_client_delete_success'),
        ], 200);
    }
}
