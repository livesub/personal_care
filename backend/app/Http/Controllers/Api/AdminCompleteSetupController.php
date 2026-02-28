<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\ReturnsApiError;
use App\Http\Controllers\Controller;
use App\Http\Requests\AdminCompleteSetupRequest;
use App\Models\Admin;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

/**
 * 초기 임시 계정 폭파(Self-Destruct) — 보안 핵심.
 * - 조건: 현재 로그인한 계정이 초기 임시 계정(예: admin_centerCode)이고, '첫 번째 슈퍼 관리자' 생성 API 호출 시.
 * - 동작 순서:
 *   1. 새 슈퍼 관리자 계정(admins) 생성.
 *   2. 생성 성공 시, 현재 로그인 중인 임시 계정(자신)을 DB에서 Hard Delete.
 *   3. 강제 로그아웃 처리 및 성공 메시지 반환.
 * - 폭파 대상: login_id로 검색하지 않음. 현재 로그인 중인 그 임시 계정만 정확히 delete() 함.
 */
class AdminCompleteSetupController extends Controller
{
    use ReturnsApiError;

    private const CODE_UNAUTHENTICATED = 'ERR_AUTH_001';
    private const CODE_FORBIDDEN = 'ERR_AUTH_002';

    /** 킬 스위치: 이 패턴으로 로그인한 경우에만 세션 폭파·히스토리 초기화 (정식 아이디는 유지) */
    private const TEMP_LOGIN_ID_BLACKLIST = ['admin', 'manager', 'root', 'staff', 'system'];

    public function __invoke(AdminCompleteSetupRequest $request): JsonResponse
    {
        $admin = $request->user();
        if (! $admin instanceof Admin) {
            return $this->errorResponse(
                self::CODE_UNAUTHENTICATED,
                __('auth_unauthenticated'),
                'User is not an Admin.',
                401
            );
        }
        if (! $admin->is_temp_account) {
            return $this->errorResponse(
                self::CODE_FORBIDDEN,
                __('admin_complete_setup_temp_only'),
                'Only temporary admin accounts can complete setup.',
                403
            );
        }

        $currentLoginId = strtolower((string) $admin->login_id);
        $wasTempAdmin = in_array($currentLoginId, self::TEMP_LOGIN_ID_BLACKLIST, true)
            || str_starts_with($currentLoginId, 'admin_');

        $validated = $request->validated();
        $newLoginId = strtolower((string) $validated['new_login_id']);
        $newPassword = strtolower((string) $validated['new_password']);

        $centerId = $admin->center_id;
        // 첫 번째 슈퍼 관리자: 임시 계정 전환 시 항상 super 로 생성 (명세 보안 요구)
        $newRole = (strtolower((string) ($admin->role ?? 'staff')) === 'super') ? 'super' : 'staff';

        DB::transaction(function () use ($admin, $newLoginId, $newPassword, $centerId, $newRole): void {
            // 1. 새 슈퍼/스태프 관리자 계정 생성
            Admin::create([
                'center_id' => $centerId,
                'login_id' => $newLoginId,
                'password' => $newPassword,
                'name' => $admin->name,
                'email' => $admin->email,
                'status' => 'active',
                'role' => $newRole,
                'is_temp_account' => false,
            ]);

            // 2. 현재 로그인 중인 임시 계정 Hard Delete (폭파)
            $admin->tokens()->delete();
            $admin->delete();
        });

        // 3. 강제 로그아웃
        if ($request->hasSession()) {
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }

        return response()->json([
            'message' => __('admin_complete_setup_done'),
            'was_temp_admin' => $wasTempAdmin,
        ]);
    }
}
