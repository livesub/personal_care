<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\Notice;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 보호사 앱 — 최신 공지 확인. 30초마다 호출.
 * GET /api/notices/check-new (X-Center-Id 헤더 필수, auth:sanctum)
 * 해당 센터의 가장 최신 공지 1건 id/title/content/center_name 반환.
 */
class NoticeCheckNewController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user instanceof Admin) {
            return response()->json(['message' => 'Forbidden', 'code' => 'HELPER_ONLY'], 403);
        }
        if (! $user instanceof User) {
            return response()->json(['message' => 'Invalid user type'], 403);
        }

        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
            ], 400);
        }

        $notice = Notice::withoutGlobalScopes()
            ->where('center_id', $centerId)
            ->with('center:id,name')
            ->orderByDesc('created_at')
            ->first();

        if ($notice === null) {
            return response()->json([
                'id' => null,
                'title' => null,
                'content' => null,
                'center_name' => null,
            ]);
        }

        return response()->json([
            'id' => $notice->id,
            'title' => $notice->title,
            'content' => $notice->content,
            'center_name' => $notice->center?->name,
        ]);
    }
}
