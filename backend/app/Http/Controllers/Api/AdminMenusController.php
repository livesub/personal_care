<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\Menu;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 관리자 메뉴 목록 API.
 * GET /api/admin/menus — 로그인한 관리자 role에 따라 is_staff_accessible 필터.
 */
class AdminMenusController extends Controller
{
    /**
     * staff면 is_staff_accessible=true 메뉴만, super면 전체 반환.
     */
    public function __invoke(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user instanceof Admin) {
            return response()->json(['message' => __('auth_unauthenticated')], 401);
        }

        $query = Menu::query()->orderBy('id');
        if (strtolower((string) ($user->role ?? 'staff')) === 'staff') {
            $query->where('is_staff_accessible', true);
        }

        $menus = $query->get(['id', 'name', 'route_name', 'icon', 'is_staff_accessible']);

        return response()->json([
            'menus' => $menus->map(fn (Menu $m) => [
                'id' => $m->id,
                'name' => $m->name,
                'route_name' => $m->route_name,
                'icon' => $m->icon,
            ]),
        ]);
    }
}
