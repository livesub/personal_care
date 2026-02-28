<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

/**
 * admins 임시 계정 비밀번호를 Argon2id로 일괄 재저장.
 * login_id = admin_센터코드(소문자) 인 행만 갱신.
 * 실행 후 예: admin_YJU / YJU!@# 로 로그인 가능.
 */
Artisan::command('admins:rehash-passwords', function () {
    $centers = DB::table('centers')->get();
    if ($centers->isEmpty()) {
        $this->warn('센터가 없습니다.');
        return;
    }
    foreach ($centers as $center) {
        $tempLoginId = 'admin_' . strtolower($center->code);
        $plain = $center->code . '!@#';
        $hashed = Hash::driver('argon2id')->make(strtolower($plain));
        $updated = DB::table('admins')
            ->where('center_id', $center->id)
            ->where('login_id', $tempLoginId)
            ->update(['password' => $hashed]);
        if ($updated) {
            $this->info("센터 id={$center->id} code={$center->code}: {$tempLoginId} 비밀번호 Argon2id로 갱신됨.");
        }
    }
    $this->info('완료. 로그인: admin_{센터코드} / {센터코드}!@# (예: admin_YJU / YJU!@#)');
})->purpose('관리자 임시 계정 비밀번호를 Argon2id로 일괄 재저장');

/**
 * B: 관리자 초기화 후 시더로만 재생성. (다른 관리자 없음, 안전성 우선)
 * 1) 관리자용 Sanctum 토큰 삭제 2) admins 테이블 비우기 3) AdminSeeder 실행 → Argon2id만 생성.
 * 서버 재부팅·DB 전체 초기화 불필요.
 */
Artisan::command('admins:fresh-seed', function () {
    $this->warn('관리자(admins) 전부 삭제 후 시더로 다시 만듭니다. 진행할까요?');
    if (! $this->confirm('계속하려면 yes 입력', false)) {
        $this->info('취소됨.');
        return;
    }
    DB::table('personal_access_tokens')
        ->where('tokenable_type', 'App\\Models\\Admin')
        ->delete();
    DB::table('admins')->truncate();
    $this->call('db:seed', ['--class' => 'AdminSeeder']);
    $this->info('완료. 로그인: admin_{센터코드} / {센터코드}!@# (예: admin_YJU / YJU!@#)');
})->purpose('관리자 초기화 후 시더로 Argon2id 계정만 재생성 (B)');
