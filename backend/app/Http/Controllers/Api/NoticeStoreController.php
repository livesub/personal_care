<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 운영 관리 — 공지사항 등록. POST /api/admin/notices
 */
class NoticeStoreController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
            ], 500);
        }

        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'content' => ['required', 'string'],
        ], [
            'title.required' => __('notice_title_required'),
            'content.required' => __('notice_content_required'),
        ]);

        $notice = Notice::withoutGlobalScope('center')->create([
            'center_id' => $centerId,
            'title' => $validated['title'],
            'content' => $validated['content'],
        ]);

        return response()->json([
            'message' => __('notice_created'),
            'notice' => [
                'id' => $notice->id,
                'title' => $notice->title,
                'content' => $notice->content,
                'created_at' => $notice->created_at?->format('Y-m-d H:i:s'),
                'updated_at' => $notice->updated_at?->format('Y-m-d H:i:s'),
            ],
        ], 201);
    }
}
