<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\ReturnsApiError;
use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\Concerns\ReturnsAuthFailure;
use App\Models\Admin;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

/**
 * 관리자(Admin) 로그인 API. Guard/테이블 분리 명시.
 * - 관리자 로그인: admins 테이블, center_id + login_id 조합으로 인증. (Guard: admins)
 * - 보호사 로그인: users 테이블, login_id(휴대폰 번호) 기준 → HelperAuthController. 두 로직 혼용 금지.
 */
class AdminAuthController extends Controller
{
    use ReturnsAuthFailure;
    use ReturnsApiError;

    private const CODE_UNAUTHORIZED = 'ERR_AUTH_001';
    private const CODE_SERVER = 'ERR_AUTH_003';

    /** 401 응답 (표준 형식). 디버그 모드일 때만 debug 키 추가. */
    private function unauthorizedWithDebug(Request $request, int $centerId, string $loginId): JsonResponse
    {
        $payload = [
            'app' => 'Personal Care',
            'code' => self::CODE_UNAUTHORIZED,
            'message' => __('auth_failed'),
            'hint' => 'Invalid credentials or admin not found.',
        ];
        if (config('app.debug')) {
            $adminRow = DB::table('admins')
                ->where('login_id', $loginId)
                ->first();
            $centerRow = DB::table('centers')->where('id', $centerId)->first();
            $payload['debug'] = [
                'sql_admins' => 'SELECT * FROM admins WHERE login_id = '.json_encode($loginId),
                'admins_row' => $adminRow ? (array) $adminRow : null,
                'sql_centers' => 'SELECT * FROM centers WHERE id = '.$centerId,
                'centers_row' => $centerRow ? (array) $centerRow : null,
            ];
            if (isset($payload['debug']['admins_row']['password'])) {
                $payload['debug']['admins_row']['password'] = '(masked)';
            }
        }

        return response()->json($payload, 401);
    }

    public function login(Request $request): JsonResponse
    {
        $request->validate(
            [
                'center_id' => ['required', 'integer', 'exists:centers,id'],
                'login_id' => ['required', 'string', 'max:50'],
                'password' => ['required', 'string'],
            ],
            [
                'center_id.required' => __('admin_login_center_required'),
                'center_id.integer' => __('admin_login_center_required'),
                'center_id.exists' => __('forgot_center_exists'),
                'login_id.required' => __('admin_login_id_required'),
                'login_id.max' => __('admin_login_id_max'),
                'password.required' => __('admin_login_password_required'),
            ]
        );

        $centerId = (int) $request->input('center_id');
        $loginId = strtolower($request->input('login_id'));
        $password = $request->input('password');

        try {
            // login_id는 전역 유일. center_id 없이 조회하여 충돌 방지.
            $row = DB::table('admins')
                ->where('login_id', $loginId)
                ->first();

            if (! $row) {
                return $this->unauthorizedWithDebug($request, $centerId, $loginId);
            }

            if (! Hash::driver('argon2id')->check($password, $row->password)) {
                return $this->unauthorizedWithDebug($request, $centerId, $loginId);
            }

            // 요청한 센터가 해당 관리자 소속 센터와 일치해야 함.
            if ((int) $row->center_id !== $centerId) {
                return $this->unauthorizedWithDebug($request, $centerId, $loginId);
            }

            $admin = Admin::find($row->id);
            if (! $admin) {
                return $this->unauthorizedWithDebug($request, $centerId, $loginId);
            }

            $inactive = $this->inactiveStatusResponse($admin->status, __('auth_inactive'));
            if ($inactive !== null) {
                return $inactive;
            }

            // Sanctum 수동 인증 및 토큰 발급
            Auth::guard('admins')->setUser($admin);
            $token = $admin->createToken('admin')->plainTextToken;

            return response()->json([
                'token' => $token,
                'access_token' => $token,
                'token_type' => 'Bearer',
                'user' => [
                    'admin_id' => $admin->id,
                    'name' => $admin->name,
                    'role' => $admin->role ?? 'staff',
                    'login_id' => $admin->login_id,
                ],
                'admin_info' => [
                    'name' => $admin->name,
                    'role' => $admin->role ?? 'staff',
                ],
                'is_temp_account' => (bool) $admin->is_temp_account,
            ]);
        } catch (\Throwable $e) {
            Log::error('Admin login error', [
                'center_id' => $centerId,
                'login_id' => $loginId,
                'exception' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
            ]);

            return $this->errorResponse(
                self::CODE_SERVER,
                __('auth_server_error'),
                'Admin login exception: '.$e->getMessage(),
                500
            );
        }
    }
}
