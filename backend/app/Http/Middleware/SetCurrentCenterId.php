<?php

namespace App\Http\Middleware;

use App\Models\Admin;
use App\Models\CenterUserAffiliation;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * API 데이터 격리: 로그인한 관리자/보호사의 center_id를 요청 단위로 설정.
 * app('current_center_id')로 Global Scope 등에서 사용.
 */
class SetCurrentCenterId
{
    /** 헤더 키: 보호사 앱이 현재 센터 ID 전달 시 사용 */
    public const HEADER_CENTER_ID = 'X-Center-Id';

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user instanceof Admin) {
            app()->instance('current_center_id', $user->center_id);

            return $next($request);
        }

        if ($user instanceof User) {
            $centerId = $request->header(self::HEADER_CENTER_ID);
            if ($centerId === null || $centerId === '') {
                return response()->json([
                    'app' => 'Personal Care',
                    'code' => 'ERR_AUTH_003',
                    'message' => __('auth_center_id_required'),
                    'hint' => 'X-Center-Id header is required for helper API.',
                ], 400);
            }

            $centerId = (int) $centerId;
            $exists = CenterUserAffiliation::where('user_id', $user->user_id)
                ->where('center_id', $centerId)
                ->exists();

            if (! $exists) {
                return response()->json([
                    'app' => 'Personal Care',
                    'code' => 'ERR_AUTH_002',
                    'message' => __('auth_center_forbidden'),
                    'hint' => 'User is not affiliated with the given center.',
                ], 403);
            }

            app()->instance('current_center_id', $centerId);

            return $next($request);
        }

        // 인증됐지만 Admin/User 아님 (이론상 없음)
        return $next($request);
    }
}
