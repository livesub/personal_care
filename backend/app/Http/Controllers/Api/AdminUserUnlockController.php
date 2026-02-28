<?php

namespace App\Http\Controllers\Api;

use App\Models\CenterUserAffiliation;
use App\Models\User;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 관리자 회원 잠금 해제 API.
 * POST /api/admin/users/{id}/unlock
 * - status → active, identity_cancel_count → 0.
 * - 해당 user가 current_center_id 소속인지 확인 후 처리.
 */
class AdminUserUnlockController extends Controller
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
                'message' => __('admin_unlock_forbidden'),
                'errors' => ['user_id' => [__('admin_unlock_forbidden')]],
            ], 403);
        }

        $user = User::find($id);
        if (! $user) {
            return response()->json([
                'message' => __('admin_unlock_user_not_found'),
                'errors' => ['user_id' => [__('admin_unlock_user_not_found')]],
            ], 404);
        }

        $user->update([
            'status' => 'active',
            'identity_cancel_count' => 0,
        ]);

        return response()->json([
            'message' => __('admin_unlock_success'),
            'user' => [
                'user_id' => $user->user_id,
                'status' => $user->status,
                'identity_cancel_count' => $user->identity_cancel_count,
            ],
        ], 200);
    }
}
