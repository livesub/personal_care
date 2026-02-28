<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Matching;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 매칭 목록 API (모니터링).
 * GET /api/admin/matchings?page=1&per_page=10
 * - current_center_id 기준. 부정 수급(중복 매칭) 행에 is_duplicate=true, 조기 종료 시 is_early_stop + early_stop_reason.
 */
class AdminMatchingsIndexController extends Controller
{
    public function __invoke(Request $request): JsonResponse
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

        $perPage = (int) $request->input('per_page', 10);
        $perPage = $perPage >= 1 && $perPage <= 100 ? $perPage : 10;

        $query = Matching::query()
            ->where('center_id', $centerId)
            ->with(['user:user_id,name', 'client:id,name,home_lat,home_lng'])
            ->orderBy('start_at', 'desc');

        // 실시간 모니터링: 날짜 필터 (start_date, end_date — "Y-m-d" 또는 ISO)
        $startDate = $request->input('start_date');
        $endDate = $request->input('end_date');
        if ($startDate !== null && $startDate !== '') {
            $parsed = \DateTimeImmutable::createFromFormat('Y-m-d', $startDate)
                ?: \DateTimeImmutable::createFromFormat(\DateTimeInterface::ATOM, $startDate)
                ?: \DateTimeImmutable::createFromFormat('Y-m-d\TH:i:s.u\Z', $startDate);
            if ($parsed !== false) {
                $query->where('start_at', '>=', $parsed->format('Y-m-d') . ' 00:00:00');
            }
        }
        if ($endDate !== null && $endDate !== '') {
            $parsed = \DateTimeImmutable::createFromFormat('Y-m-d', $endDate)
                ?: \DateTimeImmutable::createFromFormat(\DateTimeInterface::ATOM, $endDate)
                ?: \DateTimeImmutable::createFromFormat('Y-m-d\TH:i:s.u\Z', $endDate);
            if ($parsed !== false) {
                $query->where('start_at', '<=', $parsed->format('Y-m-d') . ' 23:59:59');
            }
        }

        $paginator = $query->paginate($perPage);
        $matchings = $paginator->getCollection();

        // 중복 감지: 동일 날짜 필터 적용 (실시간 모니터링 시 오늘 내 중복만)
        $allInCenterQuery = Matching::where('center_id', $centerId);
        if ($startDate !== null && $startDate !== '') {
            $parsed = \DateTimeImmutable::createFromFormat(\DateTimeInterface::ATOM, $startDate)
                ?: \DateTimeImmutable::createFromFormat('Y-m-d\TH:i:s.u\Z', $startDate);
            if ($parsed !== false) {
                $allInCenterQuery->where('start_at', '>=', $parsed->format('Y-m-d H:i:s'));
            }
        }
        if ($endDate !== null && $endDate !== '') {
            $parsed = \DateTimeImmutable::createFromFormat(\DateTimeInterface::ATOM, $endDate)
                ?: \DateTimeImmutable::createFromFormat('Y-m-d\TH:i:s.u\Z', $endDate);
            if ($parsed !== false) {
                $allInCenterQuery->where('start_at', '<=', $parsed->format('Y-m-d H:i:s'));
            }
        }
        $allInCenter = $allInCenterQuery->get(['id', 'user_id', 'start_at', 'end_at']);
        $duplicateMatchingIds = $this->duplicateMatchingIds($allInCenter);

        $now = Carbon::now();
        $list = $matchings->map(function (Matching $m) use ($duplicateMatchingIds, $now) {
            $realEnd = $m->real_end_time ? Carbon::parse($m->real_end_time) : null;
            $endAt = $m->end_at ? Carbon::parse($m->end_at) : null;
            $startAt = $m->start_at ? Carbon::parse($m->start_at) : null;
            $isEarlyStop = $realEnd !== null && $endAt !== null && $realEnd->lt($endAt);
            $notStarted = $startAt && $now->lt($startAt);
            $canEditTime = $notStarted;
            $canDelete = $notStarted;

            $client = $m->client;
            return [
                'id' => $m->id,
                'user_id' => $m->user_id,
                'user_name' => $m->user?->name ?? '',
                'client_id' => $m->client_id,
                'client_name' => $client?->name ?? '',
                'start_at' => $m->start_at ? $m->start_at->format('Y-m-d H:i:s') : null,
                'end_at' => $m->end_at ? $m->end_at->format('Y-m-d H:i:s') : null,
                'actual_start_time' => $m->actual_start_time ? Carbon::parse($m->actual_start_time)->format('Y-m-d H:i:s') : null,
                'real_end_time' => $m->real_end_time ? Carbon::parse($m->real_end_time)->format('Y-m-d H:i:s') : null,
                'early_stop_reason' => $m->early_stop_reason,
                'is_early_stop' => $isEarlyStop,
                'is_duplicate' => in_array($m->id, $duplicateMatchingIds, true),
                'hourly_wage' => (int) $m->hourly_wage,
                'can_edit_time' => $canEditTime,
                'can_delete' => $canDelete,
                'client_home_lat' => $client?->home_lat !== null ? (float) $client->home_lat : null,
                'client_home_lng' => $client?->home_lng !== null ? (float) $client->home_lng : null,
                'check_in_lat' => $m->check_in_lat !== null ? (float) $m->check_in_lat : null,
                'check_in_lng' => $m->check_in_lng !== null ? (float) $m->check_in_lng : null,
                'check_out_lat' => $m->check_out_lat !== null ? (float) $m->check_out_lat : null,
                'check_out_lng' => $m->check_out_lng !== null ? (float) $m->check_out_lng : null,
            ];
        })->values()->all();

        return response()->json([
            'matchings' => $list,
            'total' => $paginator->total(),
            'current_page' => $paginator->currentPage(),
            'per_page' => $paginator->perPage(),
            'last_page' => $paginator->lastPage(),
        ]);
    }

    /**
     * 동일 보호사가 같은 시간대에 2건 이상 케어한 매칭 id 목록 (부정 수급).
     * 겹침: (A_start < B_end) AND (A_end > B_start).
     */
    private function duplicateMatchingIds($matchings): array
    {
        $ids = [];
        $byUser = $matchings->groupBy('user_id');
        foreach ($byUser as $userId => $list) {
            $arr = $list->values()->all();
            for ($i = 0; $i < count($arr); $i++) {
                for ($j = $i + 1; $j < count($arr); $j++) {
                    $a = $arr[$i];
                    $b = $arr[$j];
                    $s1 = $a->start_at instanceof \DateTimeInterface ? $a->start_at : Carbon::parse($a->start_at);
                    $e1 = $a->end_at instanceof \DateTimeInterface ? $a->end_at : Carbon::parse($a->end_at);
                    $s2 = $b->start_at instanceof \DateTimeInterface ? $b->start_at : Carbon::parse($b->start_at);
                    $e2 = $b->end_at instanceof \DateTimeInterface ? $b->end_at : Carbon::parse($b->end_at);
                    if ($s1 < $e2 && $e1 > $s2) {
                        $ids[] = (int) $a->id;
                        $ids[] = (int) $b->id;
                    }
                }
            }
        }
        return array_values(array_unique($ids));
    }
}
