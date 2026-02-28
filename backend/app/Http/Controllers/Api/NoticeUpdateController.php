<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 운영 관리 — 공지사항 수정. PATCH /api/admin/notices/{id}
 */
class NoticeUpdateController extends Controller
{
    public function __invoke(Request $request, int $id): JsonResponse
    {
        $notice = Notice::find($id);
        if ($notice === null) {
            return response()->json(['message' => __('notice_not_found')], 404);
        }

        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'content' => ['sometimes', 'string'],
        ]);

        if (array_key_exists('title', $validated)) {
            $notice->title = $validated['title'];
        }
        if (array_key_exists('content', $validated)) {
            $notice->content = $validated['content'];
        }
        $notice->save();

        return response()->json([
            'message' => __('notice_updated'),
            'notice' => [
                'id' => $notice->id,
                'title' => $notice->title,
                'content' => $notice->content,
                'created_at' => $notice->created_at?->format('Y-m-d H:i:s'),
                'updated_at' => $notice->updated_at?->format('Y-m-d H:i:s'),
            ],
        ]);
    }
}
