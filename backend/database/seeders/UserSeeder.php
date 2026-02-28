<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * users 테이블 시드.
 * 테스트용 보호사 계정 1건 생성.
 */
class UserSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            [
                'login_id' => '01012345678',
            ],
            [
                'password' => Hash::make('password1'),
                'name' => '테스트 보호사',
                'email' => 'helper@example.com',
                'resident_no_prefix' => '721115',           // 주민번호 앞 6자리 (암호화 저장)
                'resident_no_suffix_hidden' => '1173315',   // 주민번호 뒷 7자리 (7211151173315 중 뒤 7자리, 암호화 저장)
                'status' => 'active',
                'is_first_login' => true,
            ]
        );
    }
}
