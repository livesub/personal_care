<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreHelperRequest;
use App\Models\CenterUserAffiliation;
use App\Models\User;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/**
 * 관리자 보호사 등록 API.
 * POST /api/admin/users
 * - 휴대폰(login_id) 존재 시: center_user_affiliation만 추가.
 * - 없으면: users 신규 생성 후 소속 추가.
 * - 아이디/비번 소문자 처리, 금칙어 검사는 FormRequest에서 수행.
 */
class AdminUserStoreController extends Controller
{
    public function __invoke(StoreHelperRequest $request): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
                'hint' => 'current_center_id not set.',
            ], 500);
        }

        $loginId = preg_replace('/\D/', '', $request->input('login_id'));
        $name = $request->input('name');
        $email = $request->input('email');

        $user = User::where('login_id', $loginId)->first();

        if ($user !== null) {
            // 기존 회원: 비밀번호는 받지 않고, center_user_affiliation에 소속만 추가. 기존 비밀번호 절대 변경 안 함.
            $alreadyInCenter = CenterUserAffiliation::where('center_id', $centerId)
                ->where('user_id', $user->user_id)
                ->exists();

            if ($alreadyInCenter) {
                return response()->json([
                    'message' => __('admin_helper_duplicate_phone'),
                    'errors' => ['login_id' => [__('admin_helper_duplicate_phone')]],
                ], 422);
            }

            $affiliation = CenterUserAffiliation::firstOrCreate(
                [
                    'center_id' => $centerId,
                    'user_id' => $user->user_id,
                ],
                []
            );

            return response()->json([
                'message' => __('admin_helper_affiliation_added'),
                'user' => $this->userToArray($user),
                'affiliation_added' => $affiliation->wasRecentlyCreated,
            ], 201);
        }

        // 신규 회원: password 필수(검증됨), is_first_login=true 로 생성 후 로그인 시 비밀번호 변경 유도.
        $password = strtolower((string) $request->input('password', ''));
        $user = User::create([
            'login_id' => $loginId,
            'password' => $password,
            'name' => $name,
            'email' => $email,
            'status' => 'active',
            'is_first_login' => true,
        ]);

        CenterUserAffiliation::create([
            'center_id' => $centerId,
            'user_id' => $user->user_id,
        ]);

        return response()->json([
            'message' => __('admin_helper_created'),
            'user' => $this->userToArray($user),
        ], 201);
    }

    private function userToArray(User $user): array
    {
        return [
            'user_id' => $user->user_id,
            'login_id' => $user->login_id,
            'name' => $user->name,
            'email' => $user->email,
            'status' => $user->status,
            'is_first_login' => $user->is_first_login,
            'created_at' => $user->created_at?->format('Y-m-d H:i:s'),
        ];
    }
}
