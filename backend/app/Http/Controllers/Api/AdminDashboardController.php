<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Client;
use App\Models\Matching;
use App\Models\Notice;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;

/**
 * 관리자 대시보드 메인 화면용 API.
 * GET /api/admin/dashboard
 * - current_center_id 기준. 통계 4종 + 오늘 매칭 리스트 + 최신 공지 퀵뷰.
 */
class AdminDashboardController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
            ], 400);
        }

        $today = Carbon::today(config('app.timezone', 'Asia/Seoul'));

        $center = \App\Models\Center::find($centerId);
        $totalHelpers = $center ? $center->affiliatedUsers()->count() : 0;
        $totalClients = Client::withoutGlobalScopes()->where('center_id', $centerId)->count();

        $todaySchedules = Matching::where('center_id', $centerId)
            ->whereDate('start_at', $today)
            ->count();

        $inProgressCount = Matching::where('center_id', $centerId)
            ->whereDate('start_at', $today)
            ->whereNotNull('actual_start_time')
            ->whereNull('real_end_time')
            ->count();

        $todayMatchings = Matching::where('center_id', $centerId)
            ->whereDate('start_at', $today)
            ->with(['user:user_id,name', 'client:id,name'])
            ->orderBy('start_at')
            ->get()
            ->map(function (Matching $m) {
                $status = 'waiting';
                if ($m->real_end_time !== null) {
                    $status = 'complete';
                } elseif ($m->actual_start_time !== null) {
                    $status = 'in_progress';
                }
                return [
                    'id' => $m->id,
                    'client_name' => $m->client?->name ?? '',
                    'user_name' => $m->user?->name ?? '',
                    'start_at' => $m->start_at ? $m->start_at->format('Y-m-d H:i:s') : null,
                    'end_at' => $m->end_at ? $m->end_at->format('Y-m-d H:i:s') : null,
                    'actual_start_time' => $m->actual_start_time ? Carbon::parse($m->actual_start_time)->format('Y-m-d H:i:s') : null,
                    'real_end_time' => $m->real_end_time ? Carbon::parse($m->real_end_time)->format('Y-m-d H:i:s') : null,
                    'status' => $status,
                ];
            })
            ->values()
            ->all();

        $notices = Notice::withoutGlobalScopes()
            ->where('center_id', $centerId)
            ->orderByDesc('created_at')
            ->limit(5)
            ->get(['id', 'title', 'created_at'])
            ->map(fn ($n) => [
                'id' => $n->id,
                'title' => $n->title,
                'created_at' => $n->created_at?->format('Y-m-d H:i:s'),
            ])
            ->values()
            ->all();

        return response()->json([
            'stats' => [
                'total_helpers' => $totalHelpers,
                'total_clients' => $totalClients,
                'today_schedules' => $todaySchedules,
                'in_progress_count' => $inProgressCount,
            ],
            'today_matchings' => $todayMatchings,
            'notices' => $notices,
        ]);
    }
}
