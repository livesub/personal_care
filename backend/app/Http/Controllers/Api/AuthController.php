<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\ReturnsApiError;
use App\Http\Controllers\Controller;
use App\Http\Resources\ApiMessageResource;
use App\Models\Admin;
use App\Models\Matching;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * 인증 공통 API: 로그아웃, 현재 사용자 정보(세션 복원용).
 */
class AuthController extends Controller
{
    use ReturnsApiError;

    private const CODE_UNAUTHENTICATED = 'ERR_AUTH_001';
    private const CODE_SERVER = 'ERR_AUTH_003';
    /**
     * 로그아웃: 현재 Sanctum 액세스 토큰만 삭제.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();
        return (new ApiMessageResource(__('auth_logged_out')))->response();
    }

    /**
     * 현재 로그인 사용자 정보 (로그인 응답과 동일한 형식으로 반환, 세션 복원용).
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user) {
            return $this->errorResponse(
                self::CODE_UNAUTHENTICATED,
                __('auth_unauthenticated'),
                'User not authenticated.',
                401
            );
        }

        if ($user instanceof User) {
            return response()->json($this->userToLoginPayload($user));
        }
        if ($user instanceof Admin) {
            return response()->json($this->adminToLoginPayload($user));
        }

        return $this->errorResponse(
            self::CODE_SERVER,
            __('auth_unknown_user_type'),
            'Guard returned unsupported user type.',
            500
        );
    }

    private function formatPhone(string $loginId): string
    {
        $digits = preg_replace('/\D/', '', $loginId);
        if (strlen($digits) === 11 && str_starts_with($digits, '010')) {
            return substr($digits, 0, 3) . '-' . substr($digits, 3, 4) . '-' . substr($digits, 7, 4);
        }
        return $loginId;
    }

    private function getCurrentMatching(User $user): ?Matching
    {
        $now = Carbon::now();
        return Matching::where('user_id', $user->user_id)
            ->where('start_at', '<=', $now)
            ->where('end_at', '>=', $now)
            ->with('center')
            ->orderBy('end_at')
            ->first();
    }

    /** @return array<string, mixed> */
    private function userToLoginPayload(User $user): array
    {
        $matching = $this->getCurrentMatching($user);
        $center = $matching?->center;
        if ($center === null) {
            $center = $user->affiliatedCenters()->first();
        }
        $payload = [
            'user_id' => $user->user_id,
            'name' => $user->name,
            'email' => $user->email,
            'phone_formatted' => $this->formatPhone($user->login_id),
            'center_id' => $center?->id,
            'center_name' => $center?->name,
            'end_at' => $matching?->end_at?->format('Y-m-d H:i:s'),
            'need_password_change' => (bool) $user->is_first_login,
        ];
        if ($user->is_first_login) {
            $prefix = (string) ($user->resident_no_prefix ?? '');
            $suffixRaw = (string) ($user->resident_no_suffix_hidden ?? '');
            $suffixFirst = $suffixRaw !== '' ? substr($suffixRaw, 0, 1) : '';
            $payload['resident_masked'] = ($prefix !== '' && $suffixFirst !== '') ? $prefix . '-' . $suffixFirst . '****' : null;
        }
        return $payload;
    }

    /** @return array<string, mixed> */
    private function adminToLoginPayload(Admin $admin): array
    {
        return [
            'admin_id' => $admin->id,
            'name' => $admin->name,
            'email' => $admin->email,
            'center_id' => $admin->center_id,
            'center_name' => $admin->center?->name,
            'login_id' => $admin->login_id,
            'role' => $admin->role ?? 'admin',
            'need_password_change' => (bool) $admin->is_temp_account,
        ];
    }
}
