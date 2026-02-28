<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ApiMessageResource;
use Illuminate\Http\Request;

/**
 * 로그아웃: 현재 액세스 토큰 폐기.
 * 비밀번호 변경 팝업 이탈 시 호출하여 Zombie Token 방지.
 */
class LogoutController extends Controller
{
    public function __invoke(Request $request)
    {
        $request->user()?->currentAccessToken()?->delete();
        return (new ApiMessageResource(__('auth_logged_out')))->response();
    }
}
