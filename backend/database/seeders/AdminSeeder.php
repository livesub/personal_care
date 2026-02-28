<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\Center;
use Illuminate\Database\Seeder;

/**
 * 명세: 각 센터별 초기 임시 관리자 1명.
 * - 아이디 포맷: 무조건 admin_ + center_code (예: admin_YJU, admin_UJB). 일련번호(01) 등 뒤에 숫자 붙이지 않음.
 * - 비밀번호 포맷: center_code + !@# (예: YJU!@#, UJB!@#).
 * - role: super, is_temp_account: true. 비밀번호는 Admin 모델에서 Argon2id 해시 저장.
 */
class AdminSeeder extends Seeder
{
    public function run(): void
    {
        $centers = Center::all();
        foreach ($centers as $center) {
            $loginId = 'admin_' . $center->code;
            $plainPassword = $center->code . '!@#';
            Admin::updateOrCreate(
                [
                    'center_id' => $center->id,
                    'login_id' => $loginId,
                ],
                [
                    'password' => $plainPassword,
                    'name' => '센터 관리자',
                    'email' => 'admin-' . $center->code . '@example.com',
                    'status' => 'active',
                    'role' => 'super',
                    'is_temp_account' => true,
                ]
            );
        }
    }
}
