<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\ReturnsApiError;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 보안용 계정 잠금 API.
 * POST /api/user/lock: 해당 유저의 status를 suspended로 변경.
 * auth:sanctum 보호, 토큰 소유자 본인만 잠금 가능.
 */
class UserLockController extends Controller
{
    use ReturnsApiError;

    private const CODE_UNAUTHENTICATED = 'ERR_AUTH_001';
    private const CODE_FORBIDDEN = 'ERR_AUTH_002';

    public function __invoke(Request $request): JsonResponse
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
        if (! $user instanceof \App\Models\User) {
            return $this->errorResponse(
                self::CODE_FORBIDDEN,
                __('user_lock_helper_only'),
                'Only helper (User) accounts can call this endpoint.',
                403
            );
        }

        $user->update(['status' => 'suspended']);

        return response()->json([
            'message' => __('user_lock_locked'),
            'status' => 'suspended',
        ]);
    }
}
