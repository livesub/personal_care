<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CenterSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;

/**
 * 운영 관리(설정) API. Staff·Super 모두 접근 가능. (계정 생성/삭제·정산만 Staff 403)
 * GET   /api/admin/settings - 센터별 바우처 단가 등 조회 (center_settings)
 * PATCH /api/admin/settings - voucher_unit_price 수정
 */
class AdminSettingsController extends Controller
{
    public function index(): JsonResponse
    {
        $centerId = app('current_center_id');
        $wage = $centerId !== null
            ? CenterSetting::getVoucherUnitPriceForCenter($centerId)
            : 16150;
        return response()->json([
            'default_hourly_wage' => $wage,
            'voucher_price' => $wage,
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'default_hourly_wage' => 'sometimes|integer|min:0',
        ]);

        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
            ], 500);
        }

        if (array_key_exists('default_hourly_wage', $validated) && Schema::hasTable('center_settings')) {
            CenterSetting::withoutGlobalScope('center')->updateOrCreate(
                ['center_id' => $centerId],
                ['voucher_unit_price' => $validated['default_hourly_wage']]
            );
        }

        $wage = CenterSetting::getVoucherUnitPriceForCenter($centerId);
        return response()->json([
            'message' => __('admin_complete_setup_done'),
            'default_hourly_wage' => $wage,
        ]);
    }
}
