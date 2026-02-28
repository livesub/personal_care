<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\Client;
use App\Models\Matching;
use App\Models\Notice;
use App\Models\User;
use App\Services\VoucherCalculationService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;

/**
 * 보호사 홈 화면 API (기획서 8_AI 보호사 홈.pdf, 추가 또는 이슈 개발.pdf 1단계).
 * - GET /api/helper/home: current_matching, client_voucher, today_schedules, monthly_expected_salary, notices
 *   - [상태 유지 및 복구] 로그인 시 end_time(real_end_time) IS NULL인 최신 기록 조회 → '근무 중' UI 복구
 * - POST /api/helper/matchings/{id}/start: actual_start_time 기록, status 'start'
 * - POST /api/helper/matchings/{id}/complete: work_log, early_end_reason, actual_end_time 기록, status 'complete'
 */
class HelperHomeController extends Controller
{
    private const SALARY_HOURLY = 12000;
    private static function tz(): string
    {
        return config('app.timezone');
    }

    public function home(Request $request): JsonResponse
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

        $now = Carbon::now();
        // 앱 타임존(env) 기준 오늘/이번 달 범위
        $todayForCompare = Carbon::today(self::tz());
        $monthStart = Carbon::today(self::tz())->startOfMonth();
        $monthEnd = Carbon::today(self::tz())->endOfMonth();

        // matchings 테이블에서 '보호사'를 가리키는 컬럼: helper_id 있으면 사용, 없으면 user_id (마이그레이션상 보호사 user_id)
        $matchingsTable = (new Matching)->getTable();
        $helperIdColumn = Schema::hasColumn($matchingsTable, 'helper_id') ? 'helper_id' : 'user_id';
        // 로그인한 유저 = 보호사(Helper). User 모델 PK는 user_id 이므로 getKey() === user_id
        $loggedInHelperId = $user->user_id ?? $user->getKey();

        // [상태 유지 및 복구] 진행 중: status = 'start' (보호사 본인 일정만)
        $currentMatching = Matching::where($helperIdColumn, $loggedInHelperId)
            ->where('center_id', $centerId)
            ->where('status', 'start')
            ->whereNotNull('actual_start_time')
            ->orderBy('start_at')
            ->first();

        if ($currentMatching === null) {
            // [복구] end_time IS NULL 조회: 앱 종료/브라우저 종료 후 재접속 시 미종료 근무 복구
            // actual_start_time 있으나 real_end_time 없는 최신 기록 → '근무 중'으로 복구
            $recovered = Matching::where($helperIdColumn, $loggedInHelperId)
                ->where('center_id', $centerId)
                ->whereNotNull('actual_start_time')
                ->whereNull('real_end_time')
                ->where(function ($q): void {
                    $q->whereNull('status')->orWhere('status', '!=', 'complete');
                })
                ->orderByDesc('actual_start_time')
                ->first();
            if ($recovered !== null) {
                if ($recovered->status !== 'start') {
                    $recovered->status = 'start';
                    $recovered->save();
                }
                $currentMatching = $recovered;
            }
        }

        if ($currentMatching === null) {
            // 가장 임박한 오늘 매칭 (start_at >= now 또는 아직 안 끝난 오늘 일정)
            $currentMatching = Matching::where($helperIdColumn, $loggedInHelperId)
                ->where('center_id', $centerId)
                ->where(function ($q) use ($now): void {
                    $q->where('start_at', '>=', $now)
                        ->orWhere(function ($q2) use ($now): void {
                            $q2->where('start_at', '<=', $now)
                                ->where('end_at', '>=', $now);
                        });
                })
                ->whereIn('status', [null, 'scheduled'])
                ->orderBy('start_at')
                ->first();
        }

        $currentMatching?->load(['client:id,name,voucher_balance', 'center:id,name']);

        $clientVoucher = null;
        if ($currentMatching?->client_id && $currentMatching->client) {
            $client = $currentMatching->client;
            $balance = (int) $client->voucher_balance;
            $expectedDeduction = 0;
            if ($currentMatching->status === 'start' && $currentMatching->actual_start_time) {
                $start = Carbon::parse($currentMatching->actual_start_time);
                $end = $currentMatching->real_end_time
                    ? Carbon::parse($currentMatching->real_end_time)
                    : ($currentMatching->end_at ? Carbon::parse($currentMatching->end_at) : $now);
                $expectedDeduction = app(VoucherCalculationService::class)->calculateAmount($start, $end);
            } elseif ($currentMatching->status !== 'complete' && $currentMatching->start_at && $currentMatching->end_at) {
                $expectedDeduction = app(VoucherCalculationService::class)->calculateAmount(
                    Carbon::parse($currentMatching->start_at),
                    Carbon::parse($currentMatching->end_at)
                );
            }
            $clientVoucher = [
                'client_id' => $client->id,
                'client_name' => $client->name,
                'current_balance' => $balance,
                'expected_balance_after_today' => max(0, $balance - $expectedDeduction),
            ];
        }

        // 오늘 일정: 앱 타임존 기준 "오늘 날짜"에 시작하는 모든 일정 (status 무관)
        $todayQuery = Matching::query()
            ->where($helperIdColumn, $loggedInHelperId)
            ->where('center_id', $centerId)
            ->whereDate('start_at', $todayForCompare)
            ->with(['client:id,name', 'center:id,name'])
            ->orderBy('start_at');

        $todaySchedulesRaw = $todayQuery->get();
        $todaySchedules = $todaySchedulesRaw->map(fn (Matching $m) => $this->formatMatchingForSchedule($m, $now));

        $monthlyExpectedSalary = $this->computeMonthlyExpectedSalary($loggedInHelperId, $centerId, $monthStart, $monthEnd, $now, $helperIdColumn);

        $centerIds = $user->affiliatedCenters()->pluck('centers.id')->toArray();
        $notices = [];
        if ($centerIds !== []) {
            $notices = Notice::withoutGlobalScopes()
                ->whereIn('center_id', $centerIds)
                ->with('center:id,name')
                ->orderByDesc('created_at')
                ->limit(3)
                ->get()
                ->map(fn (Notice $n) => [
                    'id' => $n->id,
                    'center_name' => $n->center?->name,
                    'title' => $n->title,
                    'content' => $n->content,
                    'created_at' => $n->created_at?->format('Y-m-d H:i:s'),
                ])
                ->toArray();
        }

        return response()->json([
            'current_matching' => $currentMatching ? $this->formatCurrentMatching($currentMatching) : null,
            'client_voucher' => $clientVoucher,
            'today_schedules' => $todaySchedules->values()->toArray(),
            'monthly_expected_salary' => $monthlyExpectedSalary,
            'notices' => $notices,
        ]);
    }

    public function start(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        if ($user instanceof Admin || ! $user instanceof User) {
            return response()->json(['message' => 'Forbidden', 'code' => 'HELPER_ONLY'], 403);
        }
        $mt = (new Matching)->getTable();
        $helperIdColumn = Schema::hasColumn($mt, 'helper_id') ? 'helper_id' : 'user_id';
        $loggedInHelperId = $user->user_id ?? $user->getKey();

        $matching = Matching::where('id', $id)
            ->where($helperIdColumn, $loggedInHelperId)
            ->first();
        if ($matching === null) {
            return response()->json(['message' => __('no_current_matching'), 'code' => 'NOT_FOUND'], 404);
        }
        if ($matching->status === 'start') {
            return response()->json(['message' => 'Already started', 'code' => 'ALREADY_STARTED'], 422);
        }
        if ($matching->status === 'complete') {
            return response()->json(['message' => 'Already completed', 'code' => 'ALREADY_COMPLETE'], 422);
        }

        $now = Carbon::now();
        $matching->actual_start_time = $now;
        $matching->status = 'start';
        $matching->save();

        return response()->json([
            'message' => __('work_started'),
            'matching' => [
                'id' => $matching->id,
                'actual_start_time' => $matching->actual_start_time->format('Y-m-d H:i:s'),
                'status' => $matching->status,
            ],
        ]);
    }

    public function complete(Request $request, int $id, VoucherCalculationService $voucherCalc): JsonResponse
    {
        $user = $request->user();
        if ($user instanceof Admin || ! $user instanceof User) {
            return response()->json(['message' => 'Forbidden', 'code' => 'HELPER_ONLY'], 403);
        }
        $mt = (new Matching)->getTable();
        $helperIdColumn = Schema::hasColumn($mt, 'helper_id') ? 'helper_id' : 'user_id';
        $loggedInHelperId = $user->user_id ?? $user->getKey();

        $matching = Matching::where('id', $id)
            ->where($helperIdColumn, $loggedInHelperId)
            ->first();
        if ($matching === null) {
            return response()->json(['message' => __('no_current_matching'), 'code' => 'NOT_FOUND'], 404);
        }
        if ($matching->status !== 'start') {
            return response()->json(['message' => 'Not in progress', 'code' => 'NOT_IN_PROGRESS'], 422);
        }

        $actualEndTime = $request->input('actual_end_time');
        if (empty($actualEndTime)) {
            return response()->json([
                'message' => 'actual_end_time is required',
                'errors' => ['actual_end_time' => ['actual_end_time is required']],
            ], 422);
        }
        $realEnd = Carbon::parse($actualEndTime); // 비교용만 사용
        $endAt = $matching->end_at ? Carbon::parse($matching->end_at) : null;
        $isEarlyEnd = $endAt && $realEnd->lt($endAt);
        $earlyEndReason = trim((string) $request->input('early_end_reason', ''));
        if ($isEarlyEnd && $earlyEndReason === '') {
            return response()->json([
                'message' => __('early_stop_reason_required'),
                'errors' => ['early_end_reason' => [__('early_stop_reason_required')]],
            ], 422);
        }

        $matching->work_log = trim((string) $request->input('work_log', '')) ?: null;
        $matching->early_end_reason = $isEarlyEnd ? $earlyEndReason : null;
        $matching->early_stop_reason = $matching->early_stop_reason ?? ($isEarlyEnd ? $earlyEndReason : null);
        $matching->real_end_time = $request->input('actual_end_time'); // 텍스트 그대로 저장
        $matching->status = 'complete';
        $matching->save();

        $client = Client::withoutGlobalScopes()->find($matching->client_id);
        if ($client !== null) {
            $start = $matching->actual_start_time ? Carbon::parse($matching->actual_start_time) : $matching->start_at;
            $end = $realEnd;
            if ($start && $end) {
                $amount = $voucherCalc->calculateAmount(Carbon::parse($start), $end);
                $client->decrement('voucher_balance', $amount);
            }
        }

        return response()->json([
            'message' => __('work_ended'),
            'matching' => [
                'id' => $matching->id,
                'real_end_time' => $matching->real_end_time->format('Y-m-d H:i:s'),
                'status' => $matching->status,
            ],
        ]);
    }

    private function formatCurrentMatching(Matching $m): array
    {
        $startAt = $m->actual_start_time ?? $m->start_at;
        return [
            'id' => $m->id,
            'client_id' => $m->client_id,
            'center_id' => $m->center_id,
            'client_name' => $m->client?->name,
            'start_at' => $m->start_at?->format('Y-m-d H:i:s'),
            'end_at' => $m->end_at?->format('Y-m-d H:i:s'),
            'actual_start_time' => $m->actual_start_time?->format('Y-m-d H:i:s'),
            'status' => $m->status,
            'center_name' => $m->center?->name,
        ];
    }

    private function formatMatchingForSchedule(Matching $m, Carbon $now): array
    {
        $status = 'scheduled';
        if ($m->status === 'complete') {
            $status = 'complete';
        } elseif ($m->status === 'start' || ($m->start_at && $m->end_at && $now->between($m->start_at, $m->end_at))) {
            $status = 'in_progress';
        }
        return [
            'id' => $m->id,
            'center_id' => $m->center_id,
            'start_at' => $m->start_at?->format('Y-m-d H:i:s'),
            'end_at' => $m->end_at?->format('Y-m-d H:i:s'),
            'client_name' => $m->client?->name,
            'status' => $status,
        ];
    }

    private function computeMonthlyExpectedSalary(int $helperId, int $centerId, Carbon $monthStart, Carbon $monthEnd, Carbon $now, string $helperIdColumn = 'user_id'): int
    {
        $matchings = Matching::where($helperIdColumn, $helperId)
            ->where('center_id', $centerId)
            ->where(function ($q) use ($monthStart, $monthEnd): void {
                $q->whereBetween('actual_start_time', [$monthStart, $monthEnd])
                    ->orWhere(function ($q2) use ($monthStart, $monthEnd): void {
                        $q2->whereNull('actual_start_time')
                            ->whereBetween('start_at', [$monthStart, $monthEnd]);
                    });
            })
            ->get();

        $totalMinutes = 0;
        foreach ($matchings as $m) {
            if ($m->status === 'complete' && $m->real_end_time) {
                $start = $m->actual_start_time ? Carbon::parse($m->actual_start_time) : $m->start_at;
                $end = Carbon::parse($m->real_end_time);
                if ($start && $end->gt($start)) {
                    $totalMinutes += (int) $start->diffInMinutes($end);
                }
            } elseif ($m->status === 'start' && $m->actual_start_time) {
                $start = Carbon::parse($m->actual_start_time);
                $end = $now;
                if ($end->gt($start)) {
                    $totalMinutes += (int) $start->diffInMinutes($end);
                }
            }
        }
        $hours = round($totalMinutes / 60, 1);
        return (int) round($hours * self::SALARY_HOURLY);
    }
}
