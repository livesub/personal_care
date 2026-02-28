<?php

namespace App\Http\Controllers\Api;

use App\Models\CenterUserAffiliation;
use App\Models\Matching;
use App\Models\User;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 관리자 회원(보호사) 목록 API.
 * GET /api/admin/users?search=&page=1&per_page=10
 * - current_center_id 소속 보호사 전원 반환(페이징만 적용, limit(1) 등 없음).
 * - search: 이름, 로그인ID(휴대폰) 부분 일치.
 * - 동일 시간대 중복 근무 여부(has_duplicate_matching) 포함.
 */
class AdminUsersIndexController extends Controller
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

        // users.center_id(Zombie 컬럼) 참조 금지. 반드시 center_user_affiliation 조인으로 "해당 센터에 소속된" 유저만 조회.
        $query = User::whereHas('affiliatedCenters', function ($q) use ($centerId): void {
            $q->where('centers.id', $centerId);
        });

        $search = $request->input('search');
        $searchField = $request->input('search_field');
        if ($search !== null && $search !== '') {
            $term = '%' . trim($search) . '%';
            if ($searchField === 'phone') {
                $query->where('login_id', 'like', $term);
            } elseif ($searchField === 'email') {
                $query->where('email', 'like', $term);
            } else {
                $query->where('name', 'like', $term);
            }
        }

        $perPage = (int) $request->input('per_page', 10);
        $perPage = $perPage >= 1 && $perPage <= 100 ? $perPage : 10;
        $paginator = $query->orderBy('name')->paginate($perPage);

        $userIdsPage = $paginator->pluck('user_id')->all();
        $duplicateUserIds = $this->userIdsWithOverlappingMatchings($centerId, $userIdsPage);

        $list = $paginator->getCollection()->map(function (User $user) use ($duplicateUserIds) {
            return [
                'user_id' => $user->user_id,
                'name' => $user->name,
                'email' => $user->email,
                'login_id' => $user->login_id ?? '',
                'login_id_masked' => $this->maskLoginId($user->login_id),
                'status' => $user->status,
                'default_hourly_wage' => (int) ($user->default_hourly_wage ?? 16150),
                'has_duplicate_matching' => in_array($user->user_id, $duplicateUserIds, true),
            ];
        })->values()->all();

        return response()->json([
            'users' => $list,
            'total' => $paginator->total(),
            'current_page' => $paginator->currentPage(),
            'per_page' => $paginator->perPage(),
            'last_page' => $paginator->lastPage(),
        ]);
    }

    /** 동일 user_id에 대해 start_at~end_at이 겹치는 배정이 있는 user_id 목록 */
    private function userIdsWithOverlappingMatchings(int $centerId, array $userIds): array
    {
        if ($userIds === []) {
            return [];
        }

        $matchings = Matching::where('center_id', $centerId)
            ->whereIn('user_id', $userIds)
            ->orderBy('user_id')
            ->orderBy('start_at')
            ->get(['id', 'user_id', 'start_at', 'end_at']);

        $duplicate = [];
        foreach ($matchings->groupBy('user_id') as $uid => $list) {
            $arr = $list->values()->all();
            for ($i = 0; $i < count($arr); $i++) {
                for ($j = $i + 1; $j < count($arr); $j++) {
                    if ($this->intervalsOverlap($arr[$i]->start_at, $arr[$i]->end_at, $arr[$j]->start_at, $arr[$j]->end_at)) {
                        $duplicate[] = (int) $uid;
                        break 2;
                    }
                }
            }
        }

        return $duplicate;
    }

    private function intervalsOverlap($s1, $e1, $s2, $e2): bool
    {
        return $s1 < $e2 && $e1 > $s2;
    }

    private function maskLoginId(?string $loginId): string
    {
        if ($loginId === null || $loginId === '') {
            return '';
        }
        $len = strlen($loginId);
        if ($len <= 4) {
            return str_repeat('*', $len);
        }

        return substr($loginId, 0, 3).str_repeat('*', $len - 4).substr($loginId, -1);
    }
}
