<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CenterSetting;
use Illuminate\Http\JsonResponse;

/**
 * 매칭 등록 팝업 호출 시 기본값 반환.
 * GET /api/admin/matchings/create
 * voucher_price(시급) 초기값: center_settings.voucher_unit_price (센터별), 없으면 16,150원.
 */
class AdminMatchingCreateController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $centerId = app('current_center_id');
        $defaultWage = $centerId !== null
            ? CenterSetting::getVoucherUnitPriceForCenter($centerId)
            : 16150;

        return response()->json([
            'voucher_price' => $defaultWage,
            'hourly_wage' => $defaultWage,
        ]);
    }
}
