<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 보호사 휴대폰 번호 조회 API. 스마트 등록용.
 * GET /api/admin/users/check?login_id=01012345678
 * 응답: { "exists": true|false, "name": "홍길동" (존재 시만) }
 */
class AdminUserCheckController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $loginId = preg_replace('/\D/', '', (string) $request->input('login_id', ''));
        if ($loginId === '' || strlen($loginId) < 10) {
            return response()->json([
                'exists' => false,
            ]);
        }

        $user = User::where('login_id', $loginId)->first();
        if ($user === null) {
            return response()->json([
                'exists' => false,
            ]);
        }

        return response()->json([
            'exists' => true,
            'name' => $user->name ?? '',
        ]);
    }
}
