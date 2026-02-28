<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notice;
use Illuminate\Http\JsonResponse;

/**
 * 운영 관리 — 공지사항 삭제. DELETE /api/admin/notices/{id}
 */
class NoticeDestroyController extends Controller
{
    public function __invoke(int $id): JsonResponse
    {
        $notice = Notice::find($id);
        if ($notice === null) {
            return response()->json(['message' => __('notice_not_found')], 404);
        }
        $notice->delete();
        return response()->json(['message' => __('notice_deleted')]);
    }
}
