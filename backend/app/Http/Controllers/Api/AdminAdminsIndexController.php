<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use Illuminate\Http\JsonResponse;

/**
 * 운영 관리 — 관리자(admins) 목록. 본인 센터만.
 * GET /api/admin/admins
 */
class AdminAdminsIndexController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
            ], 500);
        }

        $admins = Admin::where('center_id', $centerId)
            ->orderBy('created_at', 'desc')
            ->get(['id', 'name', 'login_id', 'role', 'created_at']);

        $list = $admins->map(function (Admin $a) {
            return [
                'id' => $a->id,
                'name' => $a->name,
                'login_id' => $a->login_id,
                'role' => $a->role ?? 'staff',
                'created_at' => $a->created_at ? $a->created_at->format('Y-m-d H:i:s') : null,
            ];
        })->values()->all();

        return response()->json(['admins' => $list]);
    }
}
