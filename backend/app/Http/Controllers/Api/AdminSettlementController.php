<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Matching;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * 행정관리(결과·정산) API. 문서 기준 Strict.
 * - 대상: status = 'complete' 인 데이터만 집계.
 * - 기간: actual_start_time을 앱 타임존(env) 월 기준으로 필터링.
 * - 격리: 로그인한 관리자 center_id 데이터만 조회.
 * - 급여: (총 분/60) × 12,000원 (소수점 1자리 시간).
 * - 청구: (총 분/60) × 16,150원 (문서 고정값).
 * GET /api/admin/settlement?year=2026&month=2
 * GET /api/admin/settlement/export?year=2026&month=2 → Excel 다운로드
 */
class AdminSettlementController extends Controller
{
    /** 급여 산출 시급 (원). 문서 고정 12,000원 */
    private const SALARY_HOURLY_WAGE = 12000;

    /** 청구(바우처) 단가 (원). 문서 고정 16,150원 */
    private const BILLING_UNIT_PRICE = 16150;

    public function index(Request $request): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return $this->centerIdError();
        }
        $year = (int) $request->input('year', Carbon::now()->year);
        $month = (int) $request->input('month', Carbon::now()->month);
        if ($month < 1 || $month > 12) {
            $month = Carbon::now()->month;
        }
        $data = $this->getSettlementData($centerId, $year, $month);
        return response()->json($data);
    }

    /**
     * 현재 조회 월의 [급여 내역]·[청구 내역]을 시트별로 Excel(.xlsx) 반환.
     * GET /api/admin/settlement/export?year=2026&month=2
     */
    public function export(Request $request): StreamedResponse|JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return $this->centerIdError();
        }
        $year = (int) $request->input('year', Carbon::now()->year);
        $month = (int) $request->input('month', Carbon::now()->month);
        if ($month < 1 || $month > 12) {
            $month = Carbon::now()->month;
        }
        $data = $this->getSettlementData($centerId, $year, $month);

        $spreadsheet = new Spreadsheet();
        $monthPadded = str_pad((string) $month, 2, '0', STR_PAD_LEFT);

        // 시트 1: 급여 내역
        $sheet1 = $spreadsheet->getActiveSheet();
        $sheet1->setTitle(__('settlement_sheet_salary'));
        $sheet1->setCellValue('A1', __('settlement_col_name'));
        $sheet1->setCellValue('B1', __('settlement_col_birth'));
        $sheet1->setCellValue('C1', __('settlement_col_total_hours'));
        $sheet1->setCellValue('D1', __('settlement_col_hourly_wage'));
        $sheet1->setCellValue('E1', __('settlement_col_total_amount'));
        $row = 2;
        foreach ($data['salary'] as $s) {
            $sheet1->setCellValue('A' . $row, $s['name']);
            $sheet1->setCellValue('B' . $row, $s['birth_display'] ?? '');
            $sheet1->setCellValue('C' . $row, $s['total_hours']);
            $sheet1->setCellValue('D' . $row, $s['hourly_wage']);
            $sheet1->setCellValue('E' . $row, $s['total_amount']);
            $row++;
        }

        // 시트 2: 청구 내역
        $sheet2 = $spreadsheet->createSheet();
        $sheet2->setTitle(__('settlement_sheet_voucher'));
        $sheet2->setCellValue('A1', __('settlement_col_name'));
        $sheet2->setCellValue('B1', __('settlement_col_birth'));
        $sheet2->setCellValue('C1', __('settlement_col_grade'));
        $sheet2->setCellValue('D1', __('settlement_col_total_hours'));
        $sheet2->setCellValue('E1', __('settlement_col_unit_price'));
        $sheet2->setCellValue('F1', __('settlement_col_claim_amount'));
        $row = 2;
        foreach ($data['voucher'] as $v) {
            $sheet2->setCellValue('A' . $row, $v['name']);
            $sheet2->setCellValue('B' . $row, $v['birth_display'] ?? '');
            $sheet2->setCellValue('C' . $row, $v['grade'] ?? '');
            $sheet2->setCellValue('D' . $row, $v['total_hours']);
            $sheet2->setCellValue('E' . $row, $v['unit_price']);
            $sheet2->setCellValue('F' . $row, $v['claim_amount']);
            $row++;
        }
        $sheet2->setCellValue('E' . $row, __('settlement_voucher_total'));
        $sheet2->setCellValue('F' . $row, $data['voucher_total']);

        $filename = "settlement_{$year}-{$monthPadded}.xlsx";

        return new StreamedResponse(function () use ($spreadsheet): void {
            $writer = new Xlsx($spreadsheet);
            $writer->save('php://output');
        }, 200, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition' => 'attachment; filename="' . $filename . '"',
        ]);
    }

    private function centerIdError(): JsonResponse
    {
        return response()->json([
            'app' => 'Personal Care',
            'code' => 'ERR_AUTH_003',
            'message' => __('auth_center_id_required'),
        ], 500);
    }

    /**
     * 정산 데이터 조회. status=complete만, actual_start_time 앱 타임존(env) 월 기준 필터, 문서 고정 단가.
     *
     * @return array{year: int, month: int, salary: list<array>, voucher: list<array>, voucher_total: int}
     */
    private function getSettlementData(int $centerId, int $year, int $month): array
    {
        $matchings = Matching::where('center_id', $centerId)
            ->where('status', 'complete')
            ->with(['user:user_id,name,resident_no_prefix', 'client:id,name,resident_no_prefix,disability_type,grade'])
            ->get();

        // actual_start_time/start_at → 앱 타임존(env) 월 기준 필터
        $inMonth = static function (Matching $m) use ($year, $month): bool {
            $startAt = $m->actual_start_time ?? $m->start_at;
            if ($startAt === null) {
                return false;
            }
            $start = Carbon::parse($startAt);
            return (int) $start->format('Y') === $year && (int) $start->format('n') === $month;
        };

        $matchingsInMonth = $matchings->filter($inMonth);

        $salaryByUser = [];
        foreach ($matchingsInMonth->groupBy('user_id') as $userId => $list) {
            $totalMinutes = 0;
            $details = [];
            foreach ($list as $m) {
                $start = $m->start_at ? Carbon::parse($m->start_at) : null;
                $end = $m->real_end_time ? Carbon::parse($m->real_end_time) : null;
                if ($start && $end && $end->gt($start)) {
                    $mins = (int) $start->diffInMinutes($end);
                    $totalMinutes += $mins;
                    $hours = round($mins / 60, 1);
                    $amount = (int) round($hours * self::SALARY_HOURLY_WAGE);
                    $details[] = [
                        'date' => $start->format('Y-m-d'),
                        'start_time' => $start->format('H:i'),
                        'end_time' => $end->format('H:i'),
                        'minutes' => $mins,
                        'hours' => $hours,
                        'amount' => $amount,
                    ];
                }
            }
            $totalHours = round($totalMinutes / 60, 1);
            $user = $list->first()->user;
            $salaryByUser[] = [
                'user_id' => $userId,
                'name' => $user?->name ?? '',
                'birth_display' => $this->formatBirthFromResidentPrefix($user?->resident_no_prefix),
                'total_minutes' => $totalMinutes,
                'total_hours' => $totalHours,
                'hourly_wage' => self::SALARY_HOURLY_WAGE,
                'total_amount' => (int) round($totalHours * self::SALARY_HOURLY_WAGE),
                'details' => $details,
            ];
        }
        usort($salaryByUser, fn ($a, $b) => strcmp($a['name'], $b['name']));

        $voucherByClient = [];
        foreach ($matchingsInMonth->groupBy('client_id') as $clientId => $list) {
            $totalMinutes = 0;
            $details = [];
            foreach ($list as $m) {
                $start = $m->start_at ? Carbon::parse($m->start_at) : null;
                $end = $m->real_end_time ? Carbon::parse($m->real_end_time) : null;
                if ($start && $end && $end->gt($start)) {
                    $mins = (int) $start->diffInMinutes($end);
                    $totalMinutes += $mins;
                    $hours = round($mins / 60, 1);
                    $amount = (int) round($hours * self::BILLING_UNIT_PRICE);
                    $details[] = [
                        'date' => $start->format('Y-m-d'),
                        'start_time' => $start->format('H:i'),
                        'end_time' => $end->format('H:i'),
                        'minutes' => $mins,
                        'hours' => $hours,
                        'amount' => $amount,
                    ];
                }
            }
            $totalHours = round($totalMinutes / 60, 1);
            $client = $list->first()->client;
            $claimAmount = (int) round($totalHours * self::BILLING_UNIT_PRICE);
            $voucherByClient[] = [
                'client_id' => $clientId,
                'name' => $client?->name ?? '',
                'birth_display' => $this->formatBirthFromResidentPrefix($client?->resident_no_prefix),
                'grade' => $client?->grade ?? $client?->disability_type ?? '',
                'disability_type' => $client?->disability_type ?? '',
                'total_minutes' => $totalMinutes,
                'total_hours' => $totalHours,
                'unit_price' => self::BILLING_UNIT_PRICE,
                'claim_amount' => $claimAmount,
                'details' => $details,
            ];
        }
        usort($voucherByClient, fn ($a, $b) => strcmp($a['name'], $b['name']));

        $voucherTotal = array_sum(array_column($voucherByClient, 'claim_amount'));

        return [
            'year' => $year,
            'month' => $month,
            'salary' => $salaryByUser,
            'voucher' => $voucherByClient,
            'voucher_total' => $voucherTotal,
        ];
    }

    /**
     * 주민번호 앞자리(YYMMDD 또는 6자리) → 생년월일 표시(YYYY-MM-DD). 없으면 null.
     */
    private function formatBirthFromResidentPrefix(?string $prefix): ?string
    {
        if ($prefix === null || $prefix === '') {
            return null;
        }
        $digits = preg_replace('/\D/', '', $prefix);
        if (strlen($digits) < 6) {
            return null;
        }
        $yy = (int) substr($digits, 0, 2);
        $mm = substr($digits, 2, 2);
        $dd = substr($digits, 4, 2);
        $year = $yy <= 30 ? 2000 + $yy : 1900 + $yy; // 00~30 → 2000년대
        return "{$year}-{$mm}-{$dd}";
    }
}
