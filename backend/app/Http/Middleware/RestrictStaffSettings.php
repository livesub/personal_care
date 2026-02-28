<?php

namespace App\Http\Middleware;

use App\Models\Admin;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * RBAC: Staff 등급은 '운영 관리(설정)' 접근 가능.
 * Staff는 '계정 생성/삭제'(보호사)·'정산' 메뉴 접근 시 403 Forbidden.
 * Super: 모든 권한 허용.
 */
class RestrictStaffSettings
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        if (! $user instanceof Admin) {
            return $next($request);
        }

        $role = strtolower((string) ($user->role ?? 'staff'));
        if ($role !== 'staff') {
            return $next($request);
        }

        $path = $request->path();
        $method = $request->method();

        // 보호사 계정 생성: POST /api/admin/users
        if ($method === 'POST' && preg_match('#^api/admin/users$#', $path)) {
            return $this->forbidden();
        }
        // 보호사 계정 삭제: DELETE /api/admin/users/{id}
        if ($method === 'DELETE' && preg_match('#^api/admin/users/\d+#', $path)) {
            return $this->forbidden();
        }
        // 관리자 계정 추가: POST /api/admin/admins
        if ($method === 'POST' && preg_match('#^api/admin/admins$#', $path)) {
            return $this->forbidden();
        }
        // 정산 메뉴: /api/admin/settlement (추후 정산 API 추가 시)
        if (preg_match('#^api/admin/settlement#', $path)) {
            return $this->forbidden();
        }

        return $next($request);
    }

    private function forbidden(): Response
    {
        return response()->json([
            'message' => __('auth_forbidden_staff'),
            'code' => 'ERR_AUTH_002',
        ], 403);
    }
}
