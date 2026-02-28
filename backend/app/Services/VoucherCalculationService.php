<?php

namespace App\Services;

use App\Models\Holiday;
use App\Models\SystemSetting;
use Carbon\Carbon;

/**
 * 바우처 금액 계산.
 * - 기본 단가: 관리자 설정(default_hourly_wage), 미설정 시 16,150원/시간.
 * - 할증: 공휴일 또는 야간(22:00~06:00) 해당 분에 대해 단가 1.5배(50% 가산).
 */
class VoucherCalculationService
{
    private const SURCHARGE_MULTIPLIER = 1.5;

    public function getDefaultHourlyWage(): int
    {
        return SystemSetting::getDefaultHourlyWage();
    }

    /**
     * 야간: 22:00 이상 또는 06:00 미만 (0~5시, 22~23시).
     */
    public function isNightTime(Carbon $dt): bool
    {
        $h = (int) $dt->format('G');
        return $h >= 22 || $h < 6;
    }

    public function isHoliday(Carbon $dt): bool
    {
        return Holiday::isHoliday($dt);
    }

    /**
     * 서비스 구간( start ~ end )에 대한 바우처 총액(원).
     * 분 단위로 일반/할증 구분 후 합산.
     */
    public function calculateAmount(Carbon $start, Carbon $end): int
    {
        if ($end->lte($start)) {
            return 0;
        }

        $rate = $this->getDefaultHourlyWage();
        $normalMinutes = 0;
        $surchargeMinutes = 0;

        $current = $start->copy();
        while ($current->lt($end)) {
            $minuteEnd = $current->copy()->addMinute();
            if ($minuteEnd->gt($end)) {
                $minuteEnd = $end->copy();
            }
            $isSurcharge = $this->isNightTime($current) || $this->isHoliday($current);
            $minutes = (int) ceil($current->diffInSeconds($minuteEnd) / 60);
            if ($isSurcharge) {
                $surchargeMinutes += $minutes;
            } else {
                $normalMinutes += $minutes;
            }
            $current->addMinute();
        }

        $normalAmount = $normalMinutes / 60 * $rate;
        $surchargeAmount = $surchargeMinutes / 60 * $rate * self::SURCHARGE_MULTIPLIER;

        return (int) round($normalAmount + $surchargeAmount);
    }
}
