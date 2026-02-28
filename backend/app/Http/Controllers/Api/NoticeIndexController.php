<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notice;
use Illuminate\Http\JsonResponse;

/**
 * 운영 관리 — 공지사항 목록. center_id 격리(모델 Global Scope).
 * GET /api/admin/notices
 */
class NoticeIndexController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $notices = Notice::orderBy('created_at', 'desc')->get(['id', 'title', 'content', 'created_at', 'updated_at']);
        $list = $notices->map(function (Notice $n) {
            return [
                'id' => $n->id,
                'title' => $n->title,
                'content' => $n->content,
                'created_at' => $n->created_at ? $n->created_at->format('Y-m-d H:i:s') : null,
                'updated_at' => $n->updated_at ? $n->updated_at->format('Y-m-d H:i:s') : null,
            ];
        })->values()->all();
        return response()->json(['notices' => $list]);
    }
}
