<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * 운영 관리 — 관리자(admins) 추가. Super만 (미들웨어에서 Staff 403).
 * POST /api/admin/admins
 */
class AdminAdminStoreController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
            ], 500);
        }

        $validator = Validator::make($request->all(), [
            'login_id' => ['required', 'string', 'max:50'],
            'password' => ['required', 'string', 'min:10', 'max:255'],
            'name' => ['required', 'string', 'max:50'],
            'email' => ['nullable', 'string', 'email', 'max:100'],
            'role' => ['required', 'in:super,staff'],
        ], [
            'login_id.required' => __('admin_login_id_required'),
            'password.required' => __('admin_login_password_required'),
            'password.min' => __('validation_password_min'),
            'name.required' => __('admin_helper_name_required'),
            'role.in' => 'Role must be super or staff.',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first(), 'errors' => $validator->errors()], 422);
        }

        $loginId = strtolower($request->input('login_id'));
        if (Admin::where('login_id', $loginId)->exists()) {
            return response()->json(['message' => __('admin_login_id_taken')], 422);
        }

        $admin = Admin::create([
            'center_id' => $centerId,
            'login_id' => $loginId,
            'password' => $request->input('password'),
            'name' => $request->input('name'),
            'email' => $request->input('email'),
            'status' => 'active',
            'role' => $request->input('role'),
            'is_temp_account' => false,
        ]);

        return response()->json([
            'message' => __('admin_admin_created'),
            'admin' => [
                'id' => $admin->id,
                'name' => $admin->name,
                'login_id' => $admin->login_id,
                'role' => $admin->role ?? 'staff',
                'created_at' => $admin->created_at?->format('Y-m-d H:i:s'),
            ],
        ], 201);
    }
}
